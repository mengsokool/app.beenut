add_library(beenut_service_core STATIC
  app_config.cpp
  config_migrations.cpp
  counting_tracker.cpp
  control_server.cpp
  gpio_controller.cpp
  gstreamer_camera.cpp
  hardware_discovery.cpp
  onnx_yolo_engine.cpp
  power_control.cpp
  service_state.cpp
)

target_include_directories(beenut_service_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(beenut_service_core
  PUBLIC
    Qt6::Core
    Qt6::Network
    PkgConfig::GSTREAMER
    onnxruntime::onnxruntime
)

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
