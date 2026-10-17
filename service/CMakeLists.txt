cmake_minimum_required(VERSION 3.22)

project(BeenutFlutterService
  VERSION 0.1.0
  DESCRIPTION "Native camera, ONNX inference, and GPIO service for Beenut Flutter"
  LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

if(ANDROID)
  # Android lightweight FFI target (No Qt, No GStreamer)
  set(ONNXRUNTIME_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../onnxruntime-linux-aarch64-1.18.1/include")
  set(ONNXRUNTIME_LIBRARY "${CMAKE_CURRENT_SOURCE_DIR}/lib/android/libs/${ANDROID_ABI}/libonnxruntime.so")

  if(NOT TARGET onnxruntime::onnxruntime)
    add_library(onnxruntime::onnxruntime SHARED IMPORTED)
    set_target_properties(onnxruntime::onnxruntime PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${ONNXRUNTIME_INCLUDE_DIR}"
      IMPORTED_LOCATION "${ONNXRUNTIME_LIBRARY}"
    )
  endif()

  add_subdirectory(src/core)
else()
  set(CMAKE_AUTOMOC ON)

  find_package(Qt6 REQUIRED COMPONENTS Core Network)
  if(NOT WIN32)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(GSTREAMER REQUIRED IMPORTED_TARGET
      gstreamer-1.0
      gstreamer-allocators-1.0
      gstreamer-app-1.0
      gstreamer-video-1.0
    )
  else()
    find_package(PkgConfig)
    if(PkgConfig_FOUND)
      pkg_check_modules(GSTREAMER REQUIRED IMPORTED_TARGET
        gstreamer-1.0
        gstreamer-allocators-1.0
        gstreamer-app-1.0
        gstreamer-video-1.0
      )
    else()
      # Windows manual search fallback using standard SDK environment variables
      set(GST_ENV_VAR "GSTREAMER_1_0_ROOT_MSVC_X86_64")
      if(DEFINED ENV{${GST_ENV_VAR}})
        set(GST_ROOT_DIR "$ENV{${GST_ENV_VAR}}")
        include_directories("${GST_ROOT_DIR}/include" "${GST_ROOT_DIR}/include/gstreamer-1.0" "${GST_ROOT_DIR}/include/glib-2.0" "${GST_ROOT_DIR}/lib/glib-2.0/include")
        link_directories("${GST_ROOT_DIR}/lib")
        add_library(PkgConfig::GSTREAMER INTERFACE IMPORTED)
        target_link_libraries(PkgConfig::GSTREAMER INTERFACE gstreamer-1.0 gstapp-1.0 gstvideo-1.0 glib-2.0 gobject-2.0)
      else()
        message(FATAL_ERROR "GStreamer not found. Please install GStreamer MSVC SDK and set ${GST_ENV_VAR} environment variable.")
      endif()
    endif()
  endif()

  find_package(onnxruntime REQUIRED)
  find_package(ncnn QUIET)

  add_subdirectory(src/core)
  add_subdirectory(src/beenutd)

  include(CTest)
  if(BUILD_TESTING)
    add_subdirectory(tests)
  endif()
endif()
