#pragma once

#include "inference_engine.h"
#include "onnx_yolo_engine.h"
#include "ncnn_yolo_engine.h"
#include <memory>

namespace beenut {

/**
 * @brief Factory function to instantiate an IInferenceEngine based on config.engine ("onnx", "ncnn", "mock").
 */
std::unique_ptr<IInferenceEngine> createInferenceEngine(const ModelConfig& config, QObject* parent = nullptr);

}  // namespace beenut
