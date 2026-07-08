add_executable(service_tests
  ../src/beenutd/app_runtime.cpp
  service_tests.cpp
)

target_link_libraries(service_tests
  PRIVATE
    beenut_service_core
)

target_include_directories(service_tests
  PRIVATE
    ../src/beenutd
)

add_test(NAME service_tests COMMAND service_tests)
