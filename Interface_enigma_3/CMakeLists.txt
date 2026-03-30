cmake_minimum_required(VERSION 3.16)

project(Interface_enigma_3 VERSION 0.1 LANGUAGES CXX)

# --- Configuration Globale ---
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# --- Recherche de Qt ---
find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Widgets Network)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Widgets Network)

# --- Sources du Projet ---
set(PROJECT_SOURCES
    main.cpp
    mainwindow.cpp
    mainwindow.h
    mainwindow.ui
)

# --- Création de l'exécutable ---
if(${QT_VERSION_MAJOR} GREATER_EQUAL 6)
    qt_add_executable(Interface_enigma_3
        MANUAL_FINALIZATION
        ${PROJECT_SOURCES}
    )
else()
    if(ANDROID)
        add_library(Interface_enigma_3 SHARED ${PROJECT_SOURCES})
    else()
        add_executable(Interface_enigma_3 ${PROJECT_SOURCES})
    endif()
endif()

# --- Liens vers les bibliothèques Qt ---
target_link_libraries(Interface_enigma_3 PRIVATE
    Qt${QT_VERSION_MAJOR}::Widgets
    Qt${QT_VERSION_MAJOR}::Network
)

# --- Propriétés Spécifiques (Bundle / OS) ---
if(${QT_VERSION} VERSION_LESS 6.1.0)
    set(BUNDLE_ID_OPTION MACOSX_BUNDLE_GUI_IDENTIFIER com.example.Interface_enigma_3)
endif()

set_target_properties(Interface_enigma_3 PROPERTIES
    ${BUNDLE_ID_OPTION}
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

# --- Installation ---
include(GNUInstallDirs)
install(TARGETS Interface_enigma_3
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# --- Finalisation (Nécessaire pour Qt 6) ---
if(QT_VERSION_MAJOR EQUAL 6)
    qt_finalize_executable(Interface_enigma_3)
endif()
