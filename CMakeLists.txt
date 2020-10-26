cmake_minimum_required(VERSION 3.13.0 FATAL_ERROR)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake")

project(
  eu4dll
  VERSION 1.0.0
  LANGUAGES CXX)

add_subdirectory(Plugin)
add_subdirectory(Plugin64)
