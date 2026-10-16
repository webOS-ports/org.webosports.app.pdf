# The app's QML plugin: the document, its pages as images, the search and
# the library's file scan (see the headers).
add_library(pdfviewer-qml MODULE
    plugin.cpp plugin.h
    documentregistry.cpp documentregistry.h
    documentsearch.cpp documentsearch.h
    filescanner.cpp filescanner.h
    pageimageprovider.cpp pageimageprovider.h
    pdfdocument.cpp pdfdocument.h
    renderplan.cpp renderplan.h
)

# So the plugin can be found next to its qmldir when running from the build tree.
file(COPY qmldir DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

# A missing library shows when linking, not when the app loads the plugin.
target_link_options(pdfviewer-qml PRIVATE -Wl,--no-undefined)
target_link_libraries(pdfviewer-qml PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Concurrent PkgConfig::POPPLER)

install(TARGETS pdfviewer-qml DESTINATION ${PLUGIN_DIR})
install(FILES qmldir DESTINATION ${PLUGIN_DIR})
