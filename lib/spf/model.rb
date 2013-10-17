require 'ip'

require 'spf/util'


class SPF::Record
  DEFAULT_QUALIFIER    = '+';
end

class SPF::Term

  NAME_PATTERN               = / [:alpha:] [[:alnum:]\-_.]* /x

  MACRO_LITERAL_PATTERN      = /[!-$&-~]/
  MACRO_DELIMITER            = /[.\-+,\/_=]/
  MACRO_TRANSFORMERS_PATTERN = /\d*r?/
  MACRO_EXPAND_PATTERN       = /
      %
      (?:
          { [:alpha:] } #{MACRO_TRANSFORMERS_PATTERN} #{MACRO_DELIMITER}* } |
          [%_-]
      )
  /x

  MACRO_STRING_PATTERN                    = /
      (?:
          #{MACRO_EXPAND_PATTERN}  |
          #{MACRO_LITERAL_PATTERN}
      )*
  /x

  TOPLEVEL_PATTERN                        = /
      [:alnum:]+ - [[:alnum:]-]* [:alnum:]
      [:alnum:]*    [:alpha:]    [:alnum:]*
  /x

  DOMAIN_END_PATTERN         = /
      \. #{TOPLEVEL_PATTERN} \.? |
      #{MACRO_EXPAND_PATTERN}
  /x

  DOMAIN_SPEC_PATTERN        = / #{MACRO_STRING_PATTERN} #{DOMAIN_END_PATTERN} /x

  QNUM_PATTERN               = / 25[0-5] | 2[0-4]\d | 1\d\d | [1-9]\d | \d /x
  IPV4_ADDRESS_PATTERN       = / #{QNUM_PATTERN} (?: \. #{QNUM_PATTERN}){3} /x

  HEXWORD_PATTERN            = /[:xdigit:]{1,4}/

  TWO_HEXWORDS_OR_IPV4_ADDRESS_PATTERN = /
      #{HEXWORD_PATTERN} : #{HEXWORD_PATTERN} | #{IPV4_ADDRESS_PATTERN}
  /x

  IPV6_ADDRESS_PATTERN       = /
    #                x:x:x:x:x:x:x:x |     x:x:x:x:x:x:n.n.n.n
    (?: #{HEXWORD_PATTERN} : ){6}                                   #{TWO_HEXWORDS_OR_IPV4_ADDRESS_PATTERN} |
    #                 x::x:x:x:x:x:x |      x::x:x:x:x:n.n.n.n
    (?: #{HEXWORD_PATTERN} : ){1}   : (?: #{HEXWORD_PATTERN} : ){4} #{TWO_HEXWORDS_OR_IPV4_ADDRESS_PATTERN} |
    #               x[:x]::x:x:x:x:x |    x[:x]::x:x:x:n.n.n.n
    (?: #{HEXWORD_PATTERN} : ){1,2} : (?: #{HEXWORD_PATTERN} : ){3} #{TWO_HEXWORDS_OR_IPV4_ADDRESS_PATTERN} |
    #               x[:...]::x:x:x:x |    x[:...]::x:x:n.n.n.n
    (?: #{HEXWORD_PATTERN} : ){1,3} : (?: #{HEXWORD_PATTERN} : ){2} #{TWO_HEXWORDS_OR_IPV4_ADDRESS_PATTERN} |
    #                 x[:...]::x:x:x |      x[:...]::x:n.n.n.n
    (?: #{HEXWORD_PATTERN} : ){1,4} : (?: #{HEXWORD_PATTERN} : ){1} #{TWO_HEXWORDS_OR_IPV4_ADDRESS_PATTERN} |
    #                   x[:...]::x:x |        x[:...]::n.n.n.n
    (?: #{HEXWORD_PATTERN} : ){1,5} :                               #{TWO_HEXWORDS_OR_IPV4_ADDRESS_PATTERN} |
    #                     x[:...]::x |                       -
    (?: #{HEXWORD_PATTERN} : ){1,6} :     #{HEXWORD_PATTERN}                                                |
    #                      x[:...]:: |
    (?: #{HEXWORD_PATTERN} : ){1,7} :                                                                       |
    #                      ::[...:]x |                       -
 :: (?: #{HEXWORD_PATTERN} : ){0,6}       #{HEXWORD_PATTERN}                                                |
    #                              - |         ::[...:]n.n.n.n
 :: (?: #{HEXWORD_PATTERN} : ){0,5}                                 #{TWO_HEXWORDS_OR_IPV4_ADDRESS_PATTERN} |
    #                             :: |                       -
 ::
  /x

  def self.new_from_string(text, options)
    term = SPF::Term.new(options, {:text => text})
    term.parse
    return term
  end

  def parse_domain_spec(required = false)
    if @parse_text.sub!(/^#{DOMAIN_SPEC_PATTERN}/, '')
      domain_spec = $1
      domain_spec.sub!(/^(.*?)\.?$/, $1)
    elsif required
      raise SPF::TermDomainSpecExpected.new(
        "Missing required domain-spec in '#{@text}'")
    end
  end

  def parse_ipv4_address(required = false)
    if @parse_text.sub!(/^(#{IPV4_ADDRESS_PATTERN})/, '')
      @ip_address = $1
    elsif required
      raise SPF::TermIPv4AddressExpectedError.new(
        "Missing required IPv4 address in '#{@text}'");
    end
  end

  def parse_ipv4_prefix_length(required = false)
    if @parse_text.sub!(/^\/(\d+)/, '')
      bits = $1.to_i
      unless bits and bits >= 0 and bits <= 32 and $1 !~ /^0./
        raise SPF::TermIPv4PrefixLengthExpected.new(
          "Invalid IPv4 prefix length encountered in '#{@text}'")
      end
      @ipv4_prefix_length = bits
    elsif required
      raise SPF::TermIPv4PrefixLengthExpected.new(
        "Missing required IPv4 prefix length in '#{@text}")
    else
      @ipv4_prefix_length = DEFAULT_IPV4_PREFIX_LENGTH
    end
  end

  def parse_ipv4_network(required = false)
    self.parse_ipv4_address(required)
    self.parse_parse_ipv4_prefix_length
    @ip_address = IP.new("#{@ip_address}/#{@ipv4_prefix_length}")
  end

  def parse_ipv6_address(required = false)
    if @parse_text.sub!(/(#{IPV6_ADDRESS_PATTERN})(?=\/|$)/, '')
      @ip_address = $1
    elsif required
      raise SPF::TermIPv6AddressExpected.new(
        "Missing required IPv6 address in '#{@text}'")
    end
  end

  def parse_ipv6_prefix_length(required = false)
    if @parse_text.sub!(/^\/(\d+)/, '')
      bits = $1.to_i
      unless bits and bits >= 0 and bits <= 128 and $1 !~ /^0./
        raise SPF::TermIPv6PrefixLengthExpectedError.new(
          "Invalid IPv6 prefix length encountered in '#{@text}'")
        @ipv6_prefix_length = bits
      end
    elsif required
      raise SPF::TermIPvPrefixLengthExpected.new(
        "Missing required IPv6 prefix length in '#{@text}'")
    else
      @ipv6_prefix_length = DEFAULT_IPV6_PREFIX_LENGTH
    end
  end

  def parse_ipv6_network(required = false)
    self.parse_ipv6_address(required)
    self.parse_ipv6_prefix_length
    @ip_network = IP.new("#{@ip_address}/#{@ipv6_prefix_length}")
  end

  def parse_ipv4_ipv6_prefix_lengths
    self.parse_ipv4_prefix_length
    if self.instance_variable_defined?(:@ipv4_prefix_length) and # An IPv4 prefix length has been parsed, and
      @parse_text.sub!(/^\//, '')                           # another slash is following.
      # Parse an IPv6 prefix length:
      self.parse_ipv6_prefix_length(true)
    end
  end

  def text
    if self.instance_variable_defined?(:@text)
      return @text
    else
      raise SPF::NoUnparsedTextError
    end
  end

end

class SPF::Mech < SPF::Term

  DEFAULT_QUALIFIER          = SPF::Record::DEFAULT_QUALIFIER
  DEFAULT_IPV4_PREFIX_LENGTH = 32
  DEFAULT_IPV6_PREFIX_LENGTH = 128

  QUALIFIER_PATTERN          = /[+\-~\?]/
  NAME_PATTERN               = / #{NAME_PATTERN} (?= [:\/\x20] | $ ) /x

  EXPLANATION_TEMPLATES_BY_RESULT_CODE = {
    :pass     => "Sender is authorized to use '%{s}' in '%{_scope}' identity",
    :fail     => "Sender is not authorized to use '%{s}' in '%{_scope}' identity",
    :softfail => "Sender is not authorized to use '%{s}' in '%{_scope}' identity, however domain is not currently prepared for false failures",
    :neutral  => "Domain does not state whether sender is authorized to use '%{s}' in '%{_scope}' identity"
  }

  def initialize(options)
    super(options)
    if not self.instance_variable_defined?(:@parse_text)
      @parse_text = @text
    end
    if self.instance_variable_defined?(:@domain_spec) and
      not @domain_spec.is_a?(SPF::MacroString)
      @domain_spec = SPF::MacroString.new({:text => @domain_spec})
    end
  end

  def parse
    if not @parse_text
      raise SPF::NothingToParseError.new('Nothing to parse for mechanism')
    end
    @parse_qualifier
    @parse_name
    @parse_params
    @parse_end
  end

  def parse_qualifier
    if @parse_text.sub!(/(#{QUALIFIER_PATTERN})?/, '')
      @qualifier = $1 or DEFAULT_QUALIFIER
    else
      raise SPF::InvalidMechQualifierError.new(
        "Invalid qualifier encountered in '#{@text}'")
    end
  end

  def parse_name
    if self.parse_text.sub!(/^ (#{NAME_PATTERN}) (?: : (?=.) )? /x, '')
      @name = $1
    else
      raise SPF::InvalidMech.new(
        "Unexpected mechanism encountered in '#{@text}'")
    end
  end

  def parse_params
    # Parse generic string of parameters text (should be overridden in sub-classes):
    if @parse_text.sub!(/^(.*)/, '')
      @params_text = $1
    end
  end

  def parse_end
    unless @parse_text == ''
      raise SPF::JunkInTermError.new("Junk encountered in mechanism '#{@text}'")
    end
    @parse_text = nil
  end

  def qualifier
    # Read-only!
    return @qualifier if self.instance_variable_defined?(:@qualifier) and @qualifier
    return DEFAULT_QUALIFIER
  end

  def to_s
    return sprintf(
      '%s%s%s',
      @qualifier == DEFAULT_QUALIFIER ? '' : @qualifier,
      @name,
      @params ? @params : ''
    )
  end

  def domain(server, request)
    if self.instance_variable_defined?(:@domain_spec) and @domain_spec
      return @domain_spec.new(server, request)
    end
    return request.authority_domain
  end

  def match_in_domain(server, request, domain)
    domain = self.domain(server, request) unless domain

    ipv4_prefix_length = @ipv4_prefix_length
    ipv6_prefix_length = @ipv6_prefix_length
    addr_rr_type       = request.ip_address.version == 4 ? 'A' : 'AAAA'
    packet             = server.dns_lookup(domain, addr_rr_type)
    server.count_void_dns_lookup(request) unless (rrs = packet.answer)

    rrs.each do |rr|
      if rr.type == 'A'
        network = IP.new("#{rr.address}/#{ipv4_prefix_length}")
        return true if network.contains(request.ip_address)
      elsif rr.type == 'AAAA'
        network = IP.new("#{rr.address}/#{ipv6_prefix_length}")
        return true if network.contains(request.ip_address_v6)
      elsif rr.type == 'CNAME'
        # Ignore -- we should have gotten the A/AAAA records anyway.
      else
        # Unexpected RR type.
        # TODO: Generate debug info or ignore silently.
      end
    end
    return false
  end

  def explain(server, request, result)
    explanation_template = self.explanation_template(server, request, result)
    return unless explanation_template
    begin
      explanation = SPF::MacroString.new(
        :text           => explanation_template,
        :server         => server,
        :request        => request,
        :is_explanation => true
      )
      request.state(:local_explanation, explanation)
    rescue SPF::Exception
    rescue SPF::Result
    end
  end


  class A

    NAME         = 'a'
    NAME_PATTERN = /#{NAME}/i;

    def parse_params
      self.parse_domain_spec
      self.parse_ipv4_ipv6_prefix_lengths
    end

    def params
      params = ''
      if @domain_spec
        params += ':' + @domain_spec if @domain_spec
      end
      if @ipv4_prefix_length and @ipv4_prefix_length != DEFAULT_IPV4_PREFIX_LENGTH
        params += '/' + @ipv4_prefix_length
      end
      if @ipv6_prefix_length and @ipv6_prefix_length != DEFAULT_IPV6_PREFIX_LENGTH
        params += '//' + @ipv6_prefix_length
      end
      return params
    end

    def match(server, request)
      server.count_dns_interactive_terms(request)
      return self.match_in_domain(server, request)
    end

  end

  class SPF::Mech::All

    NAME         = 'all'
    NAME_PATTERN = /#{NAME}/i

    def parse_params
      # No parameters.
    end

    def match(server, request)
      return true
    end

  end

  class Exists

    NAME         = 'exists'
    NAME_PATTERN = /#{NAME}/i
      
    def parse_params
      self.parse_domain_spec(true)
    end

    def params
      return @domain_spec ? ':' + @domain_spec : nill
    end

    def match(server, request)
      server.count_dns_interactive_term(request)

      domain = self.domain(server, request)
      packet = server.dns_lookup(domain, 'A')
      rrs = (packet.answer or server.count_void_dns_lookup(request))
      rrs.each do |rr|
        return true if rr.type == 'A'
      end
      return false
    end

  end

  class IP4

    NAME         = 'ip4'
    NAME_PATTERN = /#{NAME}/i

    def parse_params
      self.parse_ipv4_network(true)
    end

    def params
      result = @ip_network.addr
      if @ip_network.masklen != @default_ipv4_prefix_length
        result += "/#{@ip_network.masklen}"
      end
      return result
    end

    def match(server, request)
      if ip_network_v6 = @ip_network.version == 4
        SPF::Util.ipv4_address_to_ipv6(@ip_network)
      else
        ip_network_v6 = @ip_network
      end
      return ip_network_v6.contains(request.ip_address_v6)
    end

  end

  class IP6

    NAME         = 'ip6'
    NAME_PATTERN = /#{NAME}/i

    def parse_params
      self.parse_ipv6_network(true)
    end

    def params
      params =  ':' + @ip_network.short
      params += '/' + @ip_network.masklen if
        @ip_network.masklen != DEFAULT_IPV6_PREFIX_LENGTH
      return params
    end

    def match(server, request)
      return self.ip_network_contains(request.ip_address_v6)
    end

  end

  class Include

    NAME         = 'include'
    NAME_PATTERN = /#{NAME}/i

    def parse_params
      self.parse_domain_spec(true)
    end

    def params
      return @domain_spec ? ':' + @domain_spec : nil
    end

    def match(server, request)
      server.count_dns_interactive_terms(request)

      # Create sub-request with mutated authority domain:
      authority_domain = self.domain(server, request)
      sub_request = request.new_sub_request({:authority_domain => authority_domain})

      # Process sub-request:
      result = server.process(sub_request)

      # Translate result of sub-request (RFC 4408, 5.9):

      return true if
        result.is_a?(SPF::Result::Pass)

      return false if
        result.is_a?(SPF::Result::Fail)     or
        result.is_a?(SPF::Result::SoftFail) or
        result.is_a?(SPF::Result::Neutral)

      server.throw_result('permerror', request,
        "Include domain '#{authority_domain}' has no applicable sender policy") if
        result.is_a?(SPF::Result::None)

      # Propagate any other results (including {Perm,Temp}Error) as-is:
      result.throw
    end
  end

  class MX
    
    NAME         = 'mx'
    NAME_PATTERN = /#{NAME}/i

    def parse_params
      self.parse_domain_spec
      self.parse_ipv4_ipv6_prefix_lengths
    end

    def params
      params = ''
      if @domain_spec
        params += ':' + @domain_spec
      end
      if @ipv4_prefix_length and @ipv4_prefix_length != DEFAULT_IPV4_PREFIX_LENGTH
        params += '/' + @ipv4_prefix_length
      end
      if @ipv6_prefix_length and @ipv6_prefix_length != DEFAULT_IPV6_PREFIX_LENGTH
        params += '//' + @ipv6_prefix_length
      end
      return params
    end

    def match(server, request)

      server.count_dns_interactive_term(request)

      target_domain = self.domain(server, request)
      mx_packet     = server.dns_lookup(target_domain, 'MX')
      mx_rrs        = (mx_packet.answer or server.count_void_dns_lookup(request))

      # Respect the MX mechanism lookups limit (RFC 4408, 5.4/3/4):
      if server.max_name_lookups_per_mx_mech
        mx_rrs = max_rrs[0, server.max_name_lookups_per_mx_mech]
      end

      # TODO: Use A records from packet's "additional" section? Probably not.

      # Check MX records:
      mx_rrs.each do |rr|
        if rr.type == 'MX'
          return true if
            self.match_in_domain(server, request, rr.exchange)
        else
          # Unexpected RR type.
          # TODO: Generate debug info or ignore silently.
        end
      end
      return false
    end

  end

  class PTR
    NAME         = 'ptr'
    NAME_PATTERN = /#{NAME}/i

    def parse_params
      self.parse_domain_spec
    end

    def params
      return @domain_spec ? ':' + @domain_spec : nil
    end

    def match(server, request)
      return SPF::Util.valid_domain_for_ip_address(
        server, request, request.ip_address, self.domain(server, request)) ?
        true : false
    end
  end
end

class SPF::Mod < SPF::Term

  def initialize(options = {})
    @parse_text  = options[:parse_text]
    @text        = options[:text]
    @domain_spec = options[:domain_spec]

    @parse_text = @text unless @parse_text

    if @domain_spec and not @domain_spec.is_a?(SPF::MacroString)
      @domain_spec = SPF::MacroString.new({:text => @domain_spec})
    end
  end

  def parse
    raise SPF::NothingToParseError('Nothing to parse for modifier') unless @parse_text
    self.parse_name
    self.parse_params(true)
    self.parse_end
  end

  def parse_name
    @parse_text.sub(/^(#{NAME_PATTERN})=/, '')
    if $1
      @name = $1
    else
      raise SPF::InvalidModError.new(
        "Unexpected modifier name encoutered in #{@text}")
    end
  end

  def parse_params(required = false)
    # Parse generic macro string of parameters text (should be overridden in sub-classes):
    @parse_text.sub(/^(#{MACRO_STRING_PATTERN})$/, '')
    if $1
      @params_text = $1
    elsif required
      raise SPF::InvalidMacroStringError.new(
        "Invalid macro string encountered in #{@text}")
    end
  end

  def parse_end
    unless @parse_text == ''
      raise SPF::JunkInTermError("Junk encountered in modifier #{@text}")
    end
    @parse_text = nil
  end

  def to_s
    return sprintf(
      '%s=%s',
      @name,
      @params ? @params : ''
    )
  end

  class SPF::Mod::GlobalMod < SPF::Mod
  end

  class SPF::PositionalMod < SPF::Mod
  end

  class SPF::UnknownMod < SPF::Mod
  end

  class SPF::Mod::Exp < SPF::Mod

    attr_reader :domain_spec

    NAME          = 'exp'
    NAME_PATTERN  = /#{NAME}/i
    PRECEDENCE    = 0.2

    def parse_params
      self.parse_domain_spec(true)
    end

    def params
      return @domain_spec
    end

    def process(server, request, result)
      begin
        exp_domain = @domain_spec.new({:server => server, :request => request})
        txt_packet = server.dns_lookup(exp_domain, 'TXT')
        txt_rrs    = txt_packet.answer.select {|x| x.type == 'TXT'}.map {|x| x.answer}
        unless text_rrs.length > 0
          server.throw_result(:permerror, request,
            "No authority explanation string available at domain '#{exp_domain}'") # RFC 4408, 6.2/4
        end
        unless text_rrs.length == 1
          server.throw_result(:permerror, request,
            "Redundant authority explanation strings found at domain '#{exp_domain}'") # RFC 4408, 6.2/4
        end
        explanation = SPF::MacroString.new(
          :text           => txt_rrs[0].char_str_list.join(''),
          :server         => server,
          :request        => request,
          :is_explanation => true
        )
        request.state(:authority_explanation, explanation)
      rescue SPF::DNSError, SPF::Result::Error
        # Ignore DNS and other errors.
      end
    end
  end

  class SPF::Mod::Redirect < SPF::Mod::GlobalMod

    attr_reader :domain_spec

    NAME          = 'redirect'
    NAME_PATTERN  = /#{NAME}/i
    PRECEDENCE    = 0.8

    def parse_params
      self.parse_domain_spec(true)
    end

    def params
      return @domain_spec
    end

    def process(server, request, result)
      server.count_dns_interactive_terms(request)

      # Only perform redirection if no mechanism matched (RFC 4408, 6.1/1):
      return unless result.is_a?(SPF::Result::NeutralByDefault)

      # Create sub-request with mutated authorithy domain:
      authority_domain = @domain_spec.new({:server => server, :request => request})
      sub_request = request.new_sub_request({:authority_domain => authority_domain})

      # Process sub-request:
      result = server.process(sub_request)

      # Translate result of sub-request (RFC 4408, 6.1/4):
      if result.is_a?(SPF::Result::None)
        server.throw_result(:permerror, request,
          "Redirect domain '#{authority_domain}' has no applicable sender policy")
      end

      # Propagate any other results as-is:
      result.throw
    end
  end
end

class SPF::Record

  attr_reader :SCOPES, :terms, :text

  RESULTS_BY_QUALIFIER = {
    ''  => :pass,
    '+' => :pass,
    '-' => :fail,
    '~' => :softfail,
    '?' => :neutral
  }

  def initialize(options)
    super(options)
    @parse_text    = @text if not self.instance_variable_defined?(:@parse_text)
    @terms       ||= []
    @global_mods ||= {}
  end

  def new_from_string(text, options)
    record = SPF::Record.new(options)
    record.parse
    return record
  end

  def parse
    unless self.instance_variable_defined?(:@parse_text)
      raise SPF::NothingToParseError.new('Nothing to parse for record')
    end
    @parse_version_tag
    @parse_term while @parse_text.length > 0
    @parse_end
  end

  def parse_version_tag
    if (
      @parse_text.sub!(/
        ^
        (
           #{SPF::Mech.qualifier_pattern}?
          (#{SPF::Mech.name_pattern})
           [^\x20]*
        )
        (?: \x20+ | $ )
        /, '') and $&
    )
      # Looks like a mechanism:
      mech_text  = $1
      mech_name  = $2.downcase
      mech_class = MECH_CLASSES[mech_name.to_sym]
      unless mech_class
        raise SPF::InvalidMech.new("Unknown mechanism type '#{mech_name}' in '#{@version_tag}' record")
      end
      mech = mech_class.new_from_string(mech_text)
      @terms << mech
    elsif (
      @parse_text.sub!(/
        ^
        (
          (#{SPF::Mod.name_pattern}) =
          [^\x20]*
        )
        (?: \x20+ | $ )
      /, '') and $&
    )
      # Looks like a modifier:
      mod_tet   = $1
      mod_name  = $2.downcase
      mod_class = MOD_CLASSES[mod_name]
      if mod_class
        # Known modifier.
        mod = mod_class.new_from_string(mod_text)
        if mod.is_a?(SPF::Mod::GlobalMod)
          # Global modifier.
          unless @global_mods[mod_name]
            raise SPF::DuplicateGlobalMod.new("Duplicate global modifier '#{mod_name}' encountered")
          end
          @global_mods[mod_name] = mod
        elsif mod.is_a?(SPF::PositionalMod)
          # Positional modifier, queue normally:
          @terms << mod
        end
      end
    else
      raise SPF::JunkInRecord.new("Junk encountered in record '#{@text}'")
    end
  end

  def global_mods
    return @global_mods.values.sort {|a,b| a.precedence <=> b.precedence }
  end

  def global_mod(mod_name)
    return @global_mods[mod_name]
  end

  def to_s
    return [@version_tag, @terms, @global_mods].join(' ')
  end

  def eval(server, request)
    raise SPF::OptionRequiredError.new('SPF server object required for record evaluation') unless server
    raise SPF::OptionRequiredError.new('Request object required for record evaluation')    unless request
  end

  class SPF::Record::V1

    MECH_CLASSES = {
      :all      => SPF::Mech::All,
      :ip4      => SPF::Mech::IP4,
      :ip6      => SPF::Mech::IP6,
      :a        => SPF::Mech::A,
      :mx       => SPF::Mech::MX,
      :ptr      => SPF::Mech::PTR,
      :exists   => SPF::Mech::Exists,
      :include  => SPF::Mech::Include
    }

    MOD_CLASSES = {
      :redirect => SPF::Mod::Redirect,
      :exp      => SPF::Mod::Exp
    }

    VERSION_TAG         = 'v=spf1'
    VERSION_TAG_PATTERN = / v=spf(1) (?= \x20 | $ ) /ix
    SCOPES              = [:helo, :mfrom]

    def initialize(options = {})
      super(options)

      @scopes ||= options[scopes]
      if @scopes and scopes.any?
        unless @scopes.length > 0
          raise SPF::InvalidScopeError.new('No scopes for v=spf1 record')
        end
        if @scopes.length == 2
          unless (
              @scopes[0] == :helo  and @scopes[1] == :mfrom or
              @scopes[0] == :mfrom and @scopes[1] == :helo)
            raise SPF::InvalidScope.new(
              "Invalid set of scopes " + @scopes.map{|x| "'#{x}'"}.join(', ') + "for v=spf1 record")
          end
        end
      end
    end
  end

  class SPF::Record::V2

    MECH_CLASSES = {
      :all      => SPF::Mech::All,
      :ip4      => SPF::Mech::IP4,
      :ip6      => SPF::Mech::IP6,
      :a        => SPF::Mech::A,
      :mx       => SPF::Mech::MX,
      :ptr      => SPF::Mech::PTR,
      :exists   => SPF::Mech::Exists,
      :include  => SPF::Mech::Include
    }

    MOD_CLASSES = {
      :redirect => SPF::Mod::Redirect,
      :exp      => SPF::Mod::Exp
    }

    VALID_SCOPE = /^(?: mfrom | pra )$/x
    VERSION_TAG_PATTERN = /
      spf(2\.0)
      \/
      ( (?: mfrom | pra ) (?: , (?: mfrom | pra ) )* )
      (?= \x20 | $ )
    /ix

    def initialize(options = {})
      # TODO: port
    end

    def parse_version_tag
      # TODO: port
    end

    def version_tag
      # TODO: port
    end
  end
end
