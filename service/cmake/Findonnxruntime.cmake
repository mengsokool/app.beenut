# Custom CMake Find Module for ONNX Runtime
# Finds headers and libraries for onnxruntime, and sets up the onnxruntime::onnxruntime target.

find_path(ONNXRUNTIME_INCLUDE_DIR
  NAMES onnxruntime_c_api.h
  PATH_SUFFIXES include include/onnxruntime
)

find_library(ONNXRUNTIME_LIBRARY
  NAMES onnxruntime
  PATH_SUFFIXES lib
)

find_file(ONNXRUNTIME_DLL
  NAMES onnxruntime.dll
  PATH_SUFFIXES lib bin
)

find_path(ONNXRUNTIME_COREML_PROVIDER_INCLUDE_DIR
  NAMES coreml_provider_factory.h onnxruntime/coreml_provider_factory.h
  PATH_SUFFIXES include/onnxruntime include
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(onnxruntime
  REQUIRED_VARS ONNXRUNTIME_LIBRARY ONNXRUNTIME_INCLUDE_DIR
)

if(onnxruntime_FOUND AND NOT TARGET onnxruntime::onnxruntime)
  add_library(onnxruntime::onnxruntime SHARED IMPORTED)
  if(WIN32)
    set_target_properties(onnxruntime::onnxruntime PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${ONNXRUNTIME_INCLUDE_DIR}"
      IMPORTED_IMPLIB "${ONNXRUNTIME_LIBRARY}"
    )
    if(ONNXRUNTIME_DLL)
      set_target_properties(onnxruntime::onnxruntime PROPERTIES
        IMPORTED_LOCATION "${ONNXRUNTIME_DLL}"
      )
    endif()
  else()
    set_target_properties(onnxruntime::onnxruntime PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${ONNXRUNTIME_INCLUDE_DIR}"
      IMPORTED_LOCATION "${ONNXRUNTIME_LIBRARY}"
    )
  endif()
endif()

mark_as_advanced(ONNXRUNTIME_INCLUDE_DIR ONNXRUNTIME_LIBRARY)
mark_as_advanced(ONNXRUNTIME_DLL)
mark_as_advanced(ONNXRUNTIME_COREML_PROVIDER_INCLUDE_DIR)
