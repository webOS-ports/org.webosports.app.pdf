# Unit tests for the plugin's C++: the render requests and plans, the
# document leases, the document itself (labels, outline, links, text,
# passwords), the search, the file scan, page drawing and the thumbnail
# cache - on the documents in data/. See README.md.
#
# Off by default, so image builds are unaffected:
#   cmake -DBUILD_TESTING=ON ...
# It needs googletest in the sysroot.

find_package(GTest REQUIRED)
find_package(Qt6 REQUIRED COMPONENTS Test)

set(PLUGIN_SRC ${PROJECT_SOURCE_DIR}/PdfViewerApp)

add_executable(pdfviewer-tests
    unit/main.cpp
    unit/testdata.h
    unit/test_documentregistry.cpp
    unit/test_documentsearch.cpp
    unit/test_filescanner.cpp
    unit/test_pageimageprovider.cpp
    unit/test_pdfdocument.cpp
    unit/test_renderplan.cpp
    ${PLUGIN_SRC}/documentregistry.cpp ${PLUGIN_SRC}/documentregistry.h
    ${PLUGIN_SRC}/documentsearch.cpp ${PLUGIN_SRC}/documentsearch.h
    ${PLUGIN_SRC}/filescanner.cpp ${PLUGIN_SRC}/filescanner.h
    ${PLUGIN_SRC}/pageimageprovider.cpp ${PLUGIN_SRC}/pageimageprovider.h
    ${PLUGIN_SRC}/pdfdocument.cpp ${PLUGIN_SRC}/pdfdocument.h
    ${PLUGIN_SRC}/renderplan.cpp ${PLUGIN_SRC}/renderplan.h
)
target_include_directories(pdfviewer-tests PRIVATE ${PLUGIN_SRC})
target_compile_definitions(pdfviewer-tests PRIVATE TEST_DATA_DIR="${CMAKE_CURRENT_SOURCE_DIR}/data")
target_link_libraries(pdfviewer-tests PRIVATE GTest::gtest Qt6::Gui Qt6::Quick Qt6::Concurrent Qt6::Test
                      PkgConfig::POPPLER)

add_test(NAME pdfviewer-unit COMMAND pdfviewer-tests)
set_tests_properties(pdfviewer-unit PROPERTIES ENVIRONMENT QT_QPA_PLATFORM=offscreen)
