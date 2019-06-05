cmake_minimum_required (VERSION 3.12)

project(
    dmfread
    VERSION 0.1.0
    LANGUAGES C CXX
)

add_executable(mul.tables mul.tables.c)
target_compile_features(mul.tables PUBLIC c_std_11)

add_executable(sin.table sin.table.c)
target_link_libraries(sin.table m)
target_compile_features(sin.table PUBLIC c_std_11)

add_custom_target(
    tables ALL
    COMMAND sin.table sin.inc
    COMMAND mul.tables mul.inc 
    BYPRODUCTS mul.inc sin.inc
)

find_package(ZLIB)

add_executable(dmfread datareader.cpp dmf.cpp main.cpp pce.cpp pcewriter.cpp)
target_link_libraries(dmfread ${ZLIB_LIBRARIES})
target_include_directories(dmfread PRIVATE ${ZLIB_INCLUDE_DIRS})
target_compile_features(dmfread PUBLIC cxx_std_11)

install(TARGETS dmfread DESTINATION bin)
install(FILES $<TARGET_FILE_DIR:mul.tables>/mul.inc $<TARGET_FILE_DIR:sin.table>/sin.inc DESTINATION pce)
install(DIRECTORY ${CMAKE_SOURCE_DIR}/pce/ DESTINATION pce)
