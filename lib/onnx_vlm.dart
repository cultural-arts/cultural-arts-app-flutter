@JS()
library onnx_vlm_wrapper;

import 'dart:js_interop';

@JS()
external JSPromise<JSString> runSmolVLM(String imageURL);

@JS()
external JSPromise<JSBoolean> loadSmolVLM();