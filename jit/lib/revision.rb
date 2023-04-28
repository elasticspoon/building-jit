class Revision
  InvalidObject = Class.new(StandardError)

  Ref = Struct.new(:name) do
    def resolve(context, type = nil)
      context.read_ref(name, type)
    end
  end

  Parent = Struct.new(:rev) do
    def resolve(context, type = nil)
      context.commit_parent(rev.resolve(context, type))
    end
  end

  Ancestor = Struct.new(:rev, :n) do
    def resolve(context, type = nil)
      oid = rev.resolve(context, type)
      n.times { oid = context.commit_parent(oid) }
      oid
    end
  end

  HintedError = Struct.new(:message, :hint)

  INVALID_NAME = %r{
^\.
| /\.
| \.\.
| /$
| \.lock$
| @\{
| [\x00-\x20*:?\[\\^~\x7f]
}x

  REF_ALIASES = {
    "@" => "HEAD"
  }.freeze

  PARENT = /^(.*)\^$/
  ANCESTOR = /^(.*)~(\d+)$/
  COMMIT = "commit".freeze

  attr_reader :errors

  def initialize(repo, expression)
    @repo = repo
    @expr = expression
    @query = Revision.parse(expression)
    @errors = []
  end

  def resolve(type = nil)
    oid = @query&.resolve(self, type)
    oid = nil if type && !load_typed_object(oid, type)

    return oid if oid

    raise InvalidObject, "Not a valid object name: '#{@expr}'"
  end

  def self.parse(revision)
    case revision
    when PARENT
      rev = Revision.parse(::Regexp.last_match(1))
      rev ? Parent.new(rev) : nil
    when ANCESTOR
      rev = Revision.parse(::Regexp.last_match(1))
      rev ? Ancestor.new(rev, ::Regexp.last_match(2)) : nil
    when INVALID_NAME
      nil
    else
      name = REF_ALIASES[revision] || revision
      Ref.new(name)
    end
  end

  def self.valid_ref?(revision)
    !INVALID_NAME.match?(revision)
  end

  def commit_parent(oid, _type = nil)
    return nil unless oid

    commit = load_typed_object(oid, COMMIT)
    commit&.parent
  end

  def read_ref(name, type = nil)
    oid = @repo.refs.read_ref(name)
    return oid if oid

    candidates = @repo.database.prefix_match(name)
    candidates = @repo.database.type_match_prefixes(candidates, type) if type

    case candidates.size
    when 1
      candidates.first
    when 0
      nil
    else
      log_ambiguous_sha1(name, candidates)
    end
  end

  private

  def log_ambiguous_sha1(name, candidates)
    objects = candidates.sort.map do |oid|
      object = @repo.database.load(oid)
      short = @repo.database.short_oid(object.oid)
      info = " #{short} #{object.type}"

      if object.type == COMMIT
        "#{info} #{object.author.short_date} - #{object.title_line}"
      else
        info
      end
    end

    message = "short SHA1 #{name} is ambiguous"
    hint = ["The candidates are:"] + objects

    @errors.push(HintedError.new(message, hint))
    nil
  end

  def load_typed_object(oid, type)
    return nil unless oid

    object = @repo.database.load(oid)

    if object.type == type
      object
    else
      message = "object #{oid} is a #{object.type}, not a #{type}"
      @errors.push(HintedError.new(message, []))
      nil
    end
  end
end
