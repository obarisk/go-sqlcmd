# frozen_string_literal: true

# SQLCMD TOOLS CLI, a multi-platform command line experience
class SqlCmdTools < Formula

  desc "SQLCMD Tools"
  homepage "https://github.com/microsoft/go-sqlcmd"
  url "{{ upstream_url }}"
  version "{{ cli_version }}"
  sha256 "{{ upstream_sha }}"

{{ bottle_hash }}

{{ resources }}

  def install

    # Get the CLI components to install
    components = [
      buildpath/"sqlcmd",
    ]

    # Install CLI
    components.each do |item|
      cd item do
        # TODO: Install
      end
    end

    (bin/"sqlcmd").write <<~EOS
      #!/usr/bin/env bash
      #{libexec}/bin/sqlcmd \"$@\"
    EOS

  end

  test do
    json_text = shell_output("#{bin}/sqlcmd --help")
    out = JSON.parse(json_text)
    # TODO: assert_equal out["stderr"], []
  end
end
