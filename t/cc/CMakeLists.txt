cmake_minimum_required(VERSION 3.13)
project(trial VERSION 0.0.1 DESCRIPTION "My lib!")
add_library(trial SHARED trial.cpp)
set_target_properties(trial PROPERTIES VERSION ${PROJECT_VERSION})
set_target_properties(trial PROPERTIES SOVERSION 1)
target_include_directories(trial PRIVATE .)
install(TARGETS trial
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
	PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
