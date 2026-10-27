if(ANDROID)
  # Compiler optimizations for ARM64 & Android NDK
  add_compile_options(
    -O3
    -ffast-math
    -ftree-vectorize
  )
  # Android lightweight FFI shared library
  add_library(beenut_core SHARED
    ffi_api.cpp
    engine_factory.cpp
    inference_engine.cpp
    ncnn_yolo_engine.cpp
    ncnn_decode.cpp
    onnx_yolo_engine.cpp
    ndk_camera_engine.cpp
  )
  target_include_directories(beenut_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
  target_compile_definitions(beenut_core PUBLIC ANDROID=1)
  target_link_libraries(beenut_core PRIVATE onnxruntime::onnxruntime android camera2ndk mediandk EGL GLESv3 log)
else()
  add_library(beenut_service_core STATIC
    app_config.cpp
    config_migrations.cpp
    counting_tracker.cpp
    control_server.cpp
    engine_factory.cpp
    gpio_controller.cpp
    gstreamer_camera.cpp
    hardware_discovery.cpp
    inference_engine.cpp
    ncnn_yolo_engine.cpp
    ncnn_decode.cpp
    onnx_yolo_engine.cpp
    power_control.cpp
    service_state.cpp
  )
  set_target_properties(beenut_service_core PROPERTIES POSITION_INDEPENDENT_CODE ON)

  target_include_directories(beenut_service_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
  target_link_libraries(beenut_service_core
    PUBLIC
      Qt6::Core
      Qt6::Network
      PkgConfig::GSTREAMER
      onnxruntime::onnxruntime
  )

  if(ncnn_FOUND OR TARGET ncnn)
    target_compile_definitions(beenut_service_core PUBLIC BEENUT_HAS_NCNN=1)
    target_link_libraries(beenut_service_core PUBLIC ncnn)
  endif()

  if(WIN32)
    target_compile_definitions(beenut_service_core
      PUBLIC
        NOMINMAX
        WIN32_LEAN_AND_MEAN
    )
  endif()

  if(APPLE)
    set_source_files_properties(hardware_discovery.cpp PROPERTIES COMPILE_FLAGS "-x objective-c++")
    target_link_libraries(beenut_service_core
      PUBLIC
        "-framework CoreFoundation"
        "-framework CoreVideo"
        "-framework IOSurface"
        "-framework AVFoundation"
    )
    if(ONNXRUNTIME_COREML_PROVIDER_INCLUDE_DIR)
      target_compile_definitions(beenut_service_core PRIVATE BEENUT_HAS_ONNXRUNTIME_COREML=1)
    endif()
  endif()

  # Shared library for Dart FFI
  add_library(beenut_core SHARED
    ffi_api.cpp
  )
  target_include_directories(beenut_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
  target_link_libraries(beenut_core PRIVATE beenut_service_core)
endif()
