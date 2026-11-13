#!/usr/bin/env python3
"""Preview or create Dopmi's saved PostHog adoption reports."""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener
from uuid import UUID


HOSTS = {"us": "https://us.posthog.com", "eu": "https://eu.posthog.com"}
GUIDE = Path(__file__).resolve().parents[1] / "docs/adoption-first-publication-operations.md"
DASHBOARD = {
    "name": "Dopmi · Adopciones",
    "description": "Primera publicación y alertas de intentos con consentimiento.",
}
FUNNEL = {
    "name": "Dopmi · Primera publicación de adopción",
    "description": "Intentos consentidos en el editor de adopción de producción.",
    "query": {
        "kind": "InsightVizNode",
        "source": {
            "kind": "FunnelsQuery",
            "dateRange": {"date_from": "-30d"},
            "funnelsFilter": {
                "funnelOrderType": "ordered",
                "funnelWindowInterval": 7,
                "funnelWindowIntervalUnit": "day",
            },
            "properties": [
                {"key": "environment", "value": ["production"], "type": "event", "operator": "exact"},
            ],
            "breakdownFilter": {"breakdown": "platform", "breakdown_type": "event"},
            "series": [
                {"kind": "EventsNode", "event": event}
                for event in (
                    "adoption_editor_started",
                    "adoption_photo_ready",
                    "adoption_details_reached",
                    "adoption_preview_reached",
                    "adoption_submit_accepted",
                )
            ],
        },
    },
}
ALERTS = (
    ("Foto principal con fallos sin resolver", 2),
    ("Editor sin envíos aceptados", 0),
)


class ConfigurationError(Exception):
    pass


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *_args, **_kwargs):
        return None


class PostHog:
    def __init__(self, region, project_id, key):
        self.host = HOSTS[region]
        self.project = f"/api/projects/{project_id}"
        self.key = key
        self.opener = build_opener(NoRedirect())

    def request(self, path, payload=None):
        method = "GET" if payload is None else "POST"
        request = Request(
            self.host + path,
            method=method,
            data=None if payload is None else json.dumps(payload).encode(),
            headers={
                "Authorization": f"Bearer {self.key}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
        )
        try:
            with self.opener.open(request, timeout=20) as response:
                return json.load(response)
        except HTTPError as error:
            raise ConfigurationError(f"{method} {path.split('?')[0]} devolvió HTTP {error.code}.") from None
        except (URLError, TimeoutError, ValueError):
            raise ConfigurationError(f"No se pudo verificar {method} {path.split('?')[0]}.") from None

    def resource(self, kind, resource_id=None, payload=None):
        path = f"{self.project}/{kind}/"
        if resource_id is not None:
            path += f"{resource_id}/"
        if kind == "insights":
            path += "?include_dashboards=true"
        return self.request(path, payload)

    def named(self, kind, name):
        matches = []
        offset = 0
        while True:
            options = {"search": name, "offset": offset, "limit": 100}
            page = self.request(f"{self.project}/{kind}/?{urlencode(options)}")
            results = page.get("results")
            if not isinstance(results, list):
                raise ConfigurationError(f"No se pudo leer la lista de {kind}.")
            matches.extend(row for row in results if row.get("name") == name)
            if len(matches) > 1:
                raise ConfigurationError(f"Hay más de un recurso llamado «{name}».")
            if not page.get("next"):
                break
            if not results or offset + len(results) >= 10000:
                raise ConfigurationError(f"No se pudo terminar de leer la lista de {kind}.")
            offset += len(results)
        if not matches:
            return None
        return self.resource(kind, resource_id(matches[0], kind))


def resource_id(resource, kind):
    identifier = resource.get("id")
    if kind == "alerts":
        if isinstance(identifier, str):
            try:
                return str(UUID(identifier))
            except ValueError:
                pass
    elif type(identifier) is int and identifier > 0:
        return identifier
    raise ConfigurationError(f"PostHog devolvió un identificador inválido para {kind}.")


def alert_definitions():
    guide = GUIDE.read_text(encoding="utf-8")
    for name, upper in ALERTS:
        section = re.escape(f"**{name}.**")
        match = re.search(rf"{section}[^#]*?\n```sql\n(.*?)\n```", guide, re.S)
        if not match:
            raise ConfigurationError(f"Falta la consulta de «{name}» en la guía.")
        yield (
            {
                "name": f"Dopmi · {name}",
                "description": "Consulta diaria de intentos consentidos en producción.",
                "query": {
                    "kind": "DataVisualizationNode",
                    "source": {"kind": "HogQLQuery", "query": match.group(1)},
                },
            },
            {
                "name": f"Dopmi · {name}",
                "enabled": True,
                "calculation_interval": "daily",
                "investigation_agent_enabled": False,
                "condition": {"type": "absolute_value"},
                "threshold": {"configuration": {"type": "absolute", "bounds": {"upper": upper}}},
                "config": {
                    "type": "HogQLAlertConfig",
                    "evaluation": "last_row",
                    "column": "incidencias",
                },
            },
        )


def contains(actual, expected):
    """Match the configured fields and allow defaults added by PostHog."""
    if isinstance(expected, dict):
        return isinstance(actual, dict) and all(
            key in actual and contains(actual[key], value) for key, value in expected.items()
        )
    if isinstance(expected, list):
        return isinstance(actual, list) and len(actual) == len(expected) and all(
            contains(item, wanted) for item, wanted in zip(actual, expected)
        )
    return actual == expected


def verify(kind, actual, expected):
    if kind == "alerts":
        # Current PostHog expands these write-side IDs into read-side objects.
        insight = actual.get("insight")
        subscribers = actual.get("subscribed_users")
        if isinstance(subscribers, list):
            subscribers = [user.get("id") if isinstance(user, dict) else user for user in subscribers]
        actual = {
            **actual,
            "insight": insight.get("id") if isinstance(insight, dict) else insight,
            "subscribed_users": subscribers,
        }
    if not contains(actual, expected):
        raise ConfigurationError(f"«{expected['name']}» existe con otra configuración en {kind}.")
    if kind == "dashboards" and actual.get("is_shared") is not False:
        raise ConfigurationError("El tablero tiene uso compartido externo o no se pudo comprobar.")
    if kind == "alerts" and actual["threshold"]["configuration"]["bounds"].get("lower") is not None:
        raise ConfigurationError(f"«{expected['name']}» tiene un umbral inferior adicional.")
    if kind == "insights" and expected["name"] == FUNNEL["name"]:
        source = actual["query"]["source"]
        extra_filters = source["funnelsFilter"].get("exclusions") or any(
            step.get("properties") or step.get("fixedProperties") or step.get("optionalInFunnel")
            for step in source["series"]
        )
        if extra_filters or source.get("aggregation_group_type_index") is not None:
            raise ConfigurationError(f"«{expected['name']}» tiene reglas adicionales en el embudo.")


def apply_reports(api, definitions):
    operator = resource_id(api.request("/api/users/@me/"), "users")
    dashboard = api.named("dashboards", DASHBOARD["name"])
    pending = []

    # Check all exact names and configurations before making the first write.
    if dashboard is not None:
        verify("dashboards", dashboard, DASHBOARD)
    for insight, alert in [(FUNNEL, None), *definitions]:
        saved_insight = api.named("insights", insight["name"])
        if saved_insight is not None:
            if dashboard is None:
                raise ConfigurationError(f"«{insight['name']}» existe sin el tablero de Dopmi.")
            verify("insights", saved_insight, {**insight, "dashboards": [dashboard["id"]]})
        saved_alert = None
        if alert is not None:
            alert = {**alert, "subscribed_users": [operator]}
            saved_alert = api.named("alerts", alert["name"])
            if saved_alert is not None:
                if saved_insight is None:
                    raise ConfigurationError(f"«{alert['name']}» existe sin la consulta de Dopmi.")
                verify("alerts", saved_alert, {**alert, "insight": saved_insight["id"]})
        pending.append((insight, saved_insight, alert, saved_alert))

    def create(kind, expected):
        if api.named(kind, expected["name"]) is not None:
            raise ConfigurationError(f"«{expected['name']}» apareció durante la ejecución. Vuelve a verificar.")
        created = api.resource(kind, payload=expected)
        identifier = resource_id(created, kind)
        actual = api.named(kind, expected["name"])
        if actual is None or resource_id(actual, kind) != identifier:
            raise ConfigurationError(f"No se pudo verificar «{expected['name']}» por nombre e identificador.")
        verify(kind, actual, expected)
        print(f"Verificado {expected['name']} ({identifier})")
        return actual

    if dashboard is None:
        dashboard = create("dashboards", DASHBOARD)
    for insight, saved_insight, alert, saved_alert in pending:
        if saved_insight is None:
            saved_insight = create("insights", {**insight, "dashboards": [dashboard["id"]]})
        if alert is not None and saved_alert is None:
            create("alerts", {**alert, "insight": saved_insight["id"]})
    print(f"Tablero verificado en {api.host}{api.project.replace('/api/projects/', '/project/')}/dashboard/{dashboard['id']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Create missing reports after preflight.")
    parser.add_argument("--region", choices=HOSTS)
    parser.add_argument("--project-id", type=int)
    args = parser.parse_args()
    definitions = list(alert_definitions())
    if not args.apply:
        print(json.dumps({"dashboard": DASHBOARD, "funnel": FUNNEL, "alerts": definitions}, ensure_ascii=True, indent=2))
        return
    if not args.region or not args.project_id or args.project_id < 1:
        parser.error("--apply requiere --region y --project-id positivo.")
    key = os.environ.get("POSTHOG_PERSONAL_API_KEY", "")
    if not re.fullmatch(r"phx_[A-Za-z0-9]+", key):
        parser.error("Configura POSTHOG_PERSONAL_API_KEY con una clave personal acotada al proyecto.")
    apply_reports(PostHog(args.region, args.project_id, key), definitions)


if __name__ == "__main__":
    try:
        main()
    except ConfigurationError as error:
        print(error, file=sys.stderr)
        sys.exit(1)
