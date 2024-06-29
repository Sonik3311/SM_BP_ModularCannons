function dprint(message, message_type, filename, network_side, module_name)
    local print_functions = {
        ["error"] = sm.log.error,
        ["info"] = sm.log.info,
        ["warning"] = sm.log.warning
    }

    local print_function = print_functions[string.lower(message_type)]

    if not print_function then
        print_function = print
    end

    local p_filename = filename and "["..(filename or "").."]" or ""
    local p_network_side = network_side and "["..(network_side or "").."]" or ""
    local p_module_name = module_name and "["..(module_name or "").."]" or ""

    print_function(p_filename..p_network_side..p_module_name, "::", message)
end
