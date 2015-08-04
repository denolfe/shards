require "../spec"
require "../dependency"
require "../errors"

module Shards
  abstract class Resolver
    PROJECTFILE_GITHUB_RE = /github\s+"(.+?\/(.+?))"(.*)/
    PROJECTFILE_GITHUB_BRANCH_RE = /"(.+?)"/

    getter :dependency

    def initialize(@dependency, @update_cache = true)
    end

    def spec(version = nil)
      if version == :installed
        path = File.join(install_path, SPEC_FILENAME)
        if File.exists?(path)
          Spec.from_file(path)
        else
          Spec.from_yaml("name: #{dependency.name}\n")
        end
      else
        Spec.from_yaml(read_spec(version))
      end
    end

    def installed?(version)
      spec(:installed).version == version
    end

    abstract def read_spec(version = nil)
    abstract def available_versions

    protected def install_path
      File.join(INSTALL_PATH, dependency.name)
    end

    protected def cleanup_install_directory
      if File.exists?(install_path)
        Shards.logger.debug "rm -rf #{escape install_path}"

        if Dir.exists?(install_path)
          #FileUtils.rm_rf(install_path)
          system("rm -rf #{escape install_path}")
        else
          File.delete(install_path)
        end
      end
    end

    def self.parse_dependencies_from_projectfile(contents)
      dependencies = Array(Hash(String, String)).new

      contents.scan(PROJECTFILE_GITHUB_RE) do |m|
        dependency = { "name" => m[2], "github" => m[1] }
        if m[3]? && (mm = m[3].match(PROJECTFILE_GITHUB_BRANCH_RE))
          dependency["branch"] = mm[1]
        end
        dependencies << dependency
      end

      dependencies
    end

    protected def escape(arg)
      "'#{arg.gsub(/'/, "\\'")}'"
    end
  end

  @@resolver_classes = {} of String => Resolver.class
  @@resolvers = {} of String => Resolver

  def self.register_resolver(name, resolver)
    @@resolver_classes[name.to_s] = resolver
  end

  def self.find_resolver(dependency, update_cache = true)
    @@resolvers[dependency.name] ||= begin
      klass = get_resolver_class(dependency.keys)
      raise Error.new("can't resolve dependency #{dependency.name} (unsupported resolver)") unless klass
      klass.new(dependency, update_cache: update_cache)
    end
  end

  private def self.get_resolver_class(names)
    names.each do |name|
      if resolver = @@resolver_classes[name.to_s]
        return resolver
      end
    end

    nil
  end
end