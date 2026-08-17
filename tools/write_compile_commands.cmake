get_filename_component(PROJECT_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

set(INPUT "${PROJECT_DIR}/build/vendor/compile_commands.json")
set(OUTPUT "${PROJECT_DIR}/compile_commands.json")
set(CC "/usr/bin/cc")

function(json_escape OUT INPUT)
    set(VALUE "${INPUT}")
    string(REPLACE "\\" "\\\\" VALUE "${VALUE}")
    string(REPLACE "\"" "\\\"" VALUE "${VALUE}")
    set("${OUT}" "${VALUE}" PARENT_SCOPE)
endfunction()

function(append_entry OUT DIRECTORY COMMAND FILE)
    json_escape(DIRECTORY_JSON "${DIRECTORY}")
    json_escape(COMMAND_JSON "${COMMAND}")
    json_escape(FILE_JSON "${FILE}")

    string(CONCAT ENTRY
        "{\n"
        "  \"directory\": \"${DIRECTORY_JSON}\",\n"
        "  \"command\": \"${COMMAND_JSON}\",\n"
        "  \"file\": \"${FILE_JSON}\"\n"
        "}"
    )
    set("${OUT}" "${${OUT}},\n${ENTRY}" PARENT_SCOPE)
endfunction()

if(NOT EXISTS "${INPUT}")
    message(FATAL_ERROR "Missing ${INPUT}")
endif()

file(READ "${INPUT}" JSON)
string(STRIP "${JSON}" JSON)
string(REGEX REPLACE "\\][ \t\r\n]*$" "" JSON "${JSON}")

set(SRC_DIR "${PROJECT_DIR}/src")
set(SDL_INCLUDE_DIR "${PROJECT_DIR}/vendor/SDL/include")
set(METAL_SOURCE "${SRC_DIR}/metal.m")
set(SDL_HEADER "${SRC_DIR}/sdl.h")

string(CONCAT METAL_COMMAND
    "${CC} "
    "-I${SRC_DIR} "
    "-I${SDL_INCLUDE_DIR} "
    "-x objective-c "
    "-fobjc-arc "
    "-c ${METAL_SOURCE}"
)

string(CONCAT SDL_HEADER_COMMAND
    "${CC} "
    "-I${SRC_DIR} "
    "-I${SDL_INCLUDE_DIR} "
    "-x c-header "
    "-c ${SDL_HEADER}"
)

append_entry(JSON
    "${PROJECT_DIR}"
    "${METAL_COMMAND}"
    "${METAL_SOURCE}"
)

append_entry(JSON
    "${PROJECT_DIR}"
    "${SDL_HEADER_COMMAND}"
    "${SDL_HEADER}"
)

file(WRITE "${OUTPUT}" "${JSON}\n]\n")
