require_relative './base'

module Command
  class Branch < Base
    def run
      create_branch

      exit 0
    end

    private

    def create_branch
      branch_name = @args[0]
      start_oid = @args[1]

      if start_oid
        revision = Revision.new(repo, start_oid)
        oid = revision.resolve(Revision::COMMIT)
      else
        oid = repo.refs.read_head
      end

      repo.refs.create_branch(branch_name, oid)
    rescue Refs::InvalidBranch, Revision::InvalidObject => e
      revision.errors.each do |err|
        warn "error: #{err.message}"
        err.hint.each { |line| warn "hint: #{line}" }
      end
      warn "fatal: #{e.message}"
      exit 128
    end
  end
end
