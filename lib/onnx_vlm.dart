@JS()
library onnx_vlm_wrapper;

import 'dart:js_interop';

@JS()
external JSPromise<JSString> runNanoVLM(String imageURL);

@JS()
external JSPromise<JSBoolean> loadNanoVLM();

@JS()
external set myMethodExposedToDart(JSFunction value);