@JS()
library vlm_wrapper;

import 'dart:js_interop';

@JS()
external JSPromise<JSString> whatsInTheImage(String imagePath);