require_relative "./base"
require_relative "../diff"
require_relative "../index/entry"
    NULL_PATH = Pathname.new("/dev/null").freeze
    NULL_OID = "0" * 40
      if @args.first == "--cached"
      a_path = Pathname.new("a").join(a.path)
      b_path = Pathname.new("b").join(b.path)
      Target.new(path, NULL_OID, nil, "")