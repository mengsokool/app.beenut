add_executable(beenutd
  app_runtime.cpp
  main.cpp
)

target_link_libraries(beenutd
  PRIVATE
    beenut_service_core
    Qt6::Core
)
