cmake_minimum_required(VERSION 3.24)

project(BeenutFlutterService
  VERSION 0.1.0
  DESCRIPTION "Native camera, ONNX inference, and GPIO service for Beenut Flutter"
  LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

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

add_subdirectory(src/core)
add_subdirectory(src/beenutd)

include(CTest)
if(BUILD_TESTING)
  add_subdirectory(tests)
endif()
