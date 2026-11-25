# Keeps Tailwind in sync with templates during development.
#
# Tailwind only regenerates CSS when a file the stylesheet imports changes.
# When a template changes, this writes a timestamp to the imported
# jit-refresh.css, which makes the frontend bundler rebuild the CSS with
# any new classes. The Ruby rebuild then waits for that bundle, so pages
# always point at the current stylesheet.
class Builders::TailwindJit < SiteBuilder
  def build
    hook :site, :pre_reload do |_site, paths|
      # Frontend-only changes (the new bundle's manifest) rebuild normally.
      next if paths.length == 1 && paths.first.end_with?("manifest.json")

      refresh_file = site.in_root_dir("frontend", "styles", "jit-refresh.css")
      File.write refresh_file, "/* #{Time.now.to_i} */"
      throw :halt # skip this rebuild; the bundle's manifest change triggers the next one
    end
  end
end
