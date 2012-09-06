class Expander

  def expand(tpl, *args)
    raise ArgumentError, "expand expects at most 2 arguments but got #{args.size}" if args.size > 2

    base_uri = nil
    variables = {}
    if args.size == 1
      if args[0].kind_of? String
        base_uri = args[0]
      elsif args[0].respond_to? :map
        # Stringify variables
        variables = Hash[args[0].map{ |k, v| [k.to_s, v] }]
      else
        raise ArgumentError, "Expected a string or something that returns to :map, but got: #{args[0].inspect}"
      end
    elsif args.size == 2
      if args[0].kind_of? String
        base_uri = args[0]
      else
        raise ArgumentError, "Expected a string, but got #{args[0]}"
      end
      if args[1].respond_to? :map
        # Stringify variables
        variables = Hash[args[1].map{ |k, v| [k.to_s, v] }]
      else
        raise ArgumentError, "Expected something that returns to :map, but got: #{args[1].inspect}"
      end
    end

    result = tokens.map{|part|
      part.expand(variables)
    }
    result_s = result.join

    return result_s unless base_uri

    match = URI_SPLIT.match(base_uri)

    if match[2] && result_s !~ HOST_REGEX
      # host not given
      result.unshift('/') unless result_s[0] == ?/
      result.unshift(match[2])
      result.unshift('//')
    end
    if result_s !~ SCHEME_REGEX
      result.unshift(':')
      result.unshift(match[1])
    end
    return result.join
  end
end