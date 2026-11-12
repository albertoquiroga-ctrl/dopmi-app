/// Amazon México listings used by the internal Android catalog.
class StoreReviewAmazonListing {
  const StoreReviewAmazonListing(this.asin, this.imageUrl);

  final String asin;
  final String imageUrl;

  static final _asinPattern = RegExp(r'^[A-Z0-9]{10}$');
  static final _imagePath = RegExp(
    r'^/images/I/[A-Za-z0-9._+%-]+\.(jpg|png|webp)$',
  );

  Uri? get imageUri {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.authority != 'm.media-amazon.com' ||
        uri.hasQuery ||
        uri.hasFragment ||
        !_imagePath.hasMatch(uri.path)) {
      return null;
    }
    return uri;
  }

  Uri? get productUri => _asinPattern.hasMatch(asin) && imageUri != null
      ? Uri.https('www.amazon.com.mx', '/dp/$asin', {'tag': 'albertoquir0f-20'})
      : null;
}

// The key is the DopMi presentation ID. The image and ASIN come from the
// same Amazon product page. Only these presentations appear in the app.
const storeReviewAmazonListings = <String, StoreReviewAmazonListing>{
  'cat-chow-adult-0-1500': StoreReviewAmazonListing(
    'B097XQQBDL',
    'https://m.media-amazon.com/images/I/71BqU5ScrQL._AC_SL1500_.jpg',
  ),
  'cat-chow-adult-0-3000': StoreReviewAmazonListing(
    'B097XRCRDH',
    'https://m.media-amazon.com/images/I/71qDe6jwlxL._AC_SL1500_.jpg',
  ),
  'cat-chow-adult-1-1500': StoreReviewAmazonListing(
    'B0153UWJGE',
    'https://m.media-amazon.com/images/I/71-MQy0e+vL._AC_SL1500_.jpg',
  ),
  'cat-chow-adult-1-3000': StoreReviewAmazonListing(
    'B0153UWKJ0',
    'https://m.media-amazon.com/images/I/714ys1cvCRL._AC_SL1500_.jpg',
  ),
  'cat-chow-adult-2-9000': StoreReviewAmazonListing(
    'B0153UWLJO',
    'https://m.media-amazon.com/images/I/71IdZvYsTjL._AC_SL1500_.jpg',
  ),
  'cat-chow-delimix-0-1500': StoreReviewAmazonListing(
    'B01MXDQOS4',
    'https://m.media-amazon.com/images/I/71C6zi7XPKL._AC_SL1500_.jpg',
  ),
  'cat-chow-delimix-0-15000': StoreReviewAmazonListing(
    'B01N5YFF78',
    'https://m.media-amazon.com/images/I/71k3WFk77CL._AC_SL1500_.jpg',
  ),
  'cat-chow-indoor-0-1500': StoreReviewAmazonListing(
    'B0153UWNME',
    'https://m.media-amazon.com/images/I/617TkN+x8YL._AC_SL1000_.jpg',
  ),
  'cat-chow-indoor-0-3000': StoreReviewAmazonListing(
    'B01N7OR8S2',
    'https://m.media-amazon.com/images/I/71kK7296WgL._AC_SL1500_.jpg',
  ),
  'cat-chow-indoor-0-9000': StoreReviewAmazonListing(
    'B01N6NE3LG',
    'https://m.media-amazon.com/images/I/51TFun2nynL._AC_SL1000_.jpg',
  ),
  'cat-chow-kitten-0-1500': StoreReviewAmazonListing(
    'B0153UWGGW',
    'https://m.media-amazon.com/images/I/61XCW4DR2mL._AC_SL1000_.jpg',
  ),
  'cat-chow-kitten-0-500': StoreReviewAmazonListing(
    'B0153UWHLG',
    'https://m.media-amazon.com/images/I/71D0OkFPqhL._AC_SL1500_.jpg',
  ),
  'cat-chow-sterilised-0-1500': StoreReviewAmazonListing(
    'B07S9GVX4Z',
    'https://m.media-amazon.com/images/I/71AEXUvp8PL._AC_SL1500_.jpg',
  ),
  'dog-chow-indoor-0-10000': StoreReviewAmazonListing(
    'B0CDYN96S7',
    'https://m.media-amazon.com/images/I/71RmbWYLRJL._AC_SL1500_.jpg',
  ),
  'dog-chow-medium-large-0-2000': StoreReviewAmazonListing(
    'B0153V7ZAI',
    'https://m.media-amazon.com/images/I/91Zldvm-LKL._AC_SL1500_.jpg',
  ),
  'dog-chow-medium-large-0-25000': StoreReviewAmazonListing(
    'B0153V80DE',
    'https://m.media-amazon.com/images/I/51ZmV+EHVaL._AC_SL1000_.jpg',
  ),
  'dog-chow-medium-large-0-4000': StoreReviewAmazonListing(
    'B01N90S22X',
    'https://m.media-amazon.com/images/I/61gJaW0BHNL._AC_SL1000_.jpg',
  ),
  'dog-chow-medium-large-0-7500': StoreReviewAmazonListing(
    'B0153V7ZTO',
    'https://m.media-amazon.com/images/I/61Ms+R0bV0L._AC_SL1000_.jpg',
  ),
  'dog-chow-mini-0-25000': StoreReviewAmazonListing(
    'B01MSIRNCV',
    'https://m.media-amazon.com/images/I/61ss3zv02bL._AC_SL1000_.jpg',
  ),
  'dog-chow-mini-0-4000': StoreReviewAmazonListing(
    'B0153V7XMS',
    'https://m.media-amazon.com/images/I/81vraNUpjTL._AC_SL1500_.jpg',
  ),
  'dog-chow-mini-0-7500': StoreReviewAmazonListing(
    'B01N30FXOM',
    'https://m.media-amazon.com/images/I/61kJVg0urJL._AC_SL1000_.jpg',
  ),
  'dog-chow-senior-0-10000': StoreReviewAmazonListing(
    'B0CDYFTVS9',
    'https://m.media-amazon.com/images/I/61vUwW+33DL._AC_SL1000_.jpg',
  ),
  'dog-chow-senior-0-7500': StoreReviewAmazonListing(
    'B0HNXRCY6V',
    'https://m.media-amazon.com/images/I/61X+zsjbRuL._AC_SL1000_.jpg',
  ),
  'excellent-dog-0-1500': StoreReviewAmazonListing(
    'B0CGYLJP6C',
    'https://m.media-amazon.com/images/I/41eFTnsq4LL._AC_SY300_SX300_QL70_ML2_.jpg',
  ),
  'excellent-dog-0-20000': StoreReviewAmazonListing(
    'B0153V4FSS',
    'https://m.media-amazon.com/images/I/51+AJH9rgnL._AC_SL1000_.jpg',
  ),
  'excellent-dog-0-4000': StoreReviewAmazonListing(
    'B0153V4E8Y',
    'https://m.media-amazon.com/images/I/61MsbGv5FNL._AC_SL1000_.jpg',
  ),
  'gatina-adult-0-15000': StoreReviewAmazonListing(
    'B0D363LYFK',
    'https://m.media-amazon.com/images/I/71BwrM7qYHL._AC_SY300_SX300_QL70_ML2_.jpg',
  ),
  'gatina-adult-0-3000': StoreReviewAmazonListing(
    'B0D363J9RV',
    'https://m.media-amazon.com/images/I/61OIOKo1VhL._AC_SY300_SX300_QL70_ML2_.jpg',
  ),
  'gatina-adult-0-9000': StoreReviewAmazonListing(
    'B087F5L54Q',
    'https://m.media-amazon.com/images/I/71SvkbQq+lL._AC_SY300_SX300_QL70_ML2_.jpg',
  ),
  'nupec-adult-small-0-2000': StoreReviewAmazonListing(
    'B0153V49XO',
    'https://m.media-amazon.com/images/I/51GzI9iM+FL._AC_SL1000_.jpg',
  ),
  'nupec-adult-small-0-8000': StoreReviewAmazonListing(
    'B0153V4AOM',
    'https://m.media-amazon.com/images/I/61o4s2qPP3L._AC_SL1215_.jpg',
  ),
  'nupec-kitten-0-1500': StoreReviewAmazonListing(
    'B07PTVHQC6',
    'https://m.media-amazon.com/images/I/61ErFe-KdPL._AC_SY300_SX300_QL70_ML2_.jpg',
  ),
  'nupec-puppy-small-0-2000': StoreReviewAmazonListing(
    'B0153V47YU',
    'https://m.media-amazon.com/images/I/51k6mawMGIL._AC_SL1000_.jpg',
  ),
  'nupec-puppy-small-0-8000': StoreReviewAmazonListing(
    'B0153V48QC',
    'https://m.media-amazon.com/images/I/51k6mawMGIL._AC_SL1000_.jpg',
  ),
  'pedigree-adult-0-20000': StoreReviewAmazonListing(
    'B0BVP3889G',
    'https://m.media-amazon.com/images/I/71L0F8lD3KL._AC_SL1500_.jpg',
  ),
  'pedigree-high-protein-0-10000': StoreReviewAmazonListing(
    'B0CYV545ZP',
    'https://m.media-amazon.com/images/I/71mmDUkthVL._AC_SL1500_.jpg',
  ),
  'pedigree-mini-0-10000': StoreReviewAmazonListing(
    'B00DUAMJDS',
    'https://m.media-amazon.com/images/I/71rwhsMeCiL._AC_SL1500_.jpg',
  ),
  'pedigree-mini-0-20000': StoreReviewAmazonListing(
    'B0B4V2VYCS',
    'https://m.media-amazon.com/images/I/71H5QZdRtwL._AC_SL1500_.jpg',
  ),
  'pedigree-mini-0-4000': StoreReviewAmazonListing(
    'B075N82QHJ',
    'https://m.media-amazon.com/images/I/71-Jjp7WJPL._AC_SL1500_.jpg',
  ),
  'pro-plan-cat-0-1500': StoreReviewAmazonListing(
    'B0CFRVSV91',
    'https://m.media-amazon.com/images/I/51BBz-+slfL._AC_SY300_SX300_QL70_ML2_.jpg',
  ),
  'pro-plan-cat-0-3000': StoreReviewAmazonListing(
    'B01MAUH50T',
    'https://m.media-amazon.com/images/I/61xYYXa5s9L._AC_SY300_SX300_QL70_ML2_.jpg',
  ),
  'pro-plan-cat-0-7500': StoreReviewAmazonListing(
    'B07G1QWY54',
    'https://m.media-amazon.com/images/I/71J4GIs1h5L._AC_SY300_SX300_QL70_ML2_.jpg',
  ),
  'pro-plan-cat-senior-0-3000': StoreReviewAmazonListing(
    'B01MCRHUAW',
    'https://m.media-amazon.com/images/I/61ao0GehQiL._AC_SY300_SX300_QL70_ML2_.jpg',
  ),
  'pro-plan-dog-medium-0-17500': StoreReviewAmazonListing(
    'B07KJ89948',
    'https://m.media-amazon.com/images/I/51SUaMKjehL._AC_SL1000_.jpg',
  ),
  'pro-plan-dog-medium-0-3000': StoreReviewAmazonListing(
    'B0153V0NS4',
    'https://m.media-amazon.com/images/I/61HmNgqM1TL._AC_SL1000_.jpg',
  ),
  'pro-plan-dog-medium-0-7500': StoreReviewAmazonListing(
    'B076CK8PFS',
    'https://m.media-amazon.com/images/I/519DmZF5o0L._AC_SL1080_.jpg',
  ),
  'pro-plan-dog-medium-0-9500': StoreReviewAmazonListing(
    'B0F7SHYY47',
    'https://m.media-amazon.com/images/I/71mwZJ0X1wL._AC_SL1500_.jpg',
  ),
  'pro-plan-dog-small-0-1000': StoreReviewAmazonListing(
    'B076CK7XPH',
    'https://m.media-amazon.com/images/I/51cjmdqIoeL._AC_SL1080_.jpg',
  ),
  'pro-plan-dog-small-0-3500': StoreReviewAmazonListing(
    'B07FYYM42Y',
    'https://m.media-amazon.com/images/I/51fIQEQI1CL._AC_SL1200_.jpg',
  ),
  'pro-plan-dog-small-0-7500': StoreReviewAmazonListing(
    'B076CK7XPQ',
    'https://m.media-amazon.com/images/I/61F3vHb2g2L._AC_SL1000_.jpg',
  ),
  'pro-plan-dog-small-0-9500': StoreReviewAmazonListing(
    'B0F7SQX7HL',
    'https://m.media-amazon.com/images/I/71e-aiJhbgL._AC_SL1500_.jpg',
  ),
  'pro-plan-sensitive-medium-0-17500': StoreReviewAmazonListing(
    'B0BTJZQ7S4',
    'https://m.media-amazon.com/images/I/61IlWfBom1L._AC_SL1241_.jpg',
  ),
  'pro-plan-sensitive-medium-0-3000': StoreReviewAmazonListing(
    'B077NGZXTF',
    'https://m.media-amazon.com/images/I/71wR0Ic8naL._AC_SL1500_.jpg',
  ),
  'pro-plan-sensitive-small-0-1000': StoreReviewAmazonListing(
    'B077S5L25B',
    'https://m.media-amazon.com/images/I/41kevVnzmML._AC_SY300_SX300_QL70_ML2_.jpg',
  ),
  'pro-plan-sensitive-small-0-3000': StoreReviewAmazonListing(
    'B077NHM1BV',
    'https://m.media-amazon.com/images/I/71JfAPRffQL._AC_SL1500_.jpg',
  ),
  'pro-plan-sensitive-small-0-7500': StoreReviewAmazonListing(
    'B077NH1XNB',
    'https://m.media-amazon.com/images/I/51naJ2K4VZL._AC_SL1000_.jpg',
  ),
  'pro-plan-sensitive-small-0-9500': StoreReviewAmazonListing(
    'B0F7SVFMLZ',
    'https://m.media-amazon.com/images/I/717dDN6xywL._AC_SL1500_.jpg',
  ),
  'pro-plan-sterilised-0-7500': StoreReviewAmazonListing(
    'B09GYSKD6B',
    'https://m.media-amazon.com/images/I/613uNPTC49L._AC_SY300_SX300_QL70_ML2_.jpg',
  ),
  'purina-one-cat-0-2000': StoreReviewAmazonListing(
    'B096MZM61J',
    'https://m.media-amazon.com/images/I/71rsY+ImBLL._AC_SL1500_.jpg',
  ),
  'purina-one-dog-small-0-3500': StoreReviewAmazonListing(
    'B096N1C82L',
    'https://m.media-amazon.com/images/I/7197MsN9ePL._AC_SL1500_.jpg',
  ),
  'royal-canin-kitten-0-1370': StoreReviewAmazonListing(
    'B0BX1HC83G',
    'https://m.media-amazon.com/images/I/71JX3QRQO8L._AC_SL1500_.jpg',
  ),
  'whiskas-adult-1-20000': StoreReviewAmazonListing(
    'B0CK38FM2J',
    'https://m.media-amazon.com/images/I/71zz5nCxX-L._AC_SL1500_.jpg',
  ),
  'whiskas-adult-1-3000': StoreReviewAmazonListing(
    'B01N0269PK',
    'https://m.media-amazon.com/images/I/71vyPPvQmPL._AC_SL1500_.jpg',
  ),
  'whiskas-adult-1-4500': StoreReviewAmazonListing(
    'B0DZ9RBNMT',
    'https://m.media-amazon.com/images/I/71A0veeq8rL._AC_SL1500_.jpg',
  ),
  'whiskas-adult-1-9000': StoreReviewAmazonListing(
    'B07CMKYWRN',
    'https://m.media-amazon.com/images/I/71f-JqHhdOL._AC_SL1500_.jpg',
  ),
  'whiskas-adult-2-3000': StoreReviewAmazonListing(
    'B0DZB3J5RN',
    'https://m.media-amazon.com/images/I/71tzENtpwaL._AC_SL1500_.jpg',
  ),
  'whiskas-kitten-1-1400': StoreReviewAmazonListing(
    'B0G73RPDG7',
    'https://m.media-amazon.com/images/I/61RABkITeJL._AC_SY300_SX300_QL70_ML2_.jpg',
  ),
};
