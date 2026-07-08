# Bundled YOLO26n

This folder contains the bundled Ultralytics YOLO26n COCO baseline model.

- `yolo26n.onnx` was exported from the upstream Ultralytics `yolo26n.pt` asset with `model.export(format="onnx", imgsz=640, opset=12)`.
- `labels.txt` contains the COCO class names.

This model is a general COCO-pretrained baseline. It is not trained specifically for nut/washer counting.
