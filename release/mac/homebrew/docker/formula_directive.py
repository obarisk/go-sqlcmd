#------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
#------------------------------------------------------------------------------

import os
import requests
import jinja2
import subprocess
import json
import codecs
import pkg_resources

from jinja2 import Environment
from contextlib import closing
from hashlib import sha256
from urllib.request import urlopen

TEMPLATE_FILE_NAME = 'formula.tpl'

RESOURCE_TEMPLATE = Environment(trim_blocks=True).from_string("""\
  resource "{{ resource.name }}" do
    url "{{ resource.url }}"
    {{ resource.checksum_type }} "{{ resource.checksum }}"
  end
""")

COMMENTED_BOTTLE_TEMPLATE = Environment(trim_blocks=True).from_string("""\
  #  bottle do
  #    root_url "{{ root_url }}"
  #    cellar :any
  #    sha256 "{{ sha256_catalina }}" => :catalina
  #    sha256 "{{ sha256_mojave }}" => :mojave
  #    sha256 "{{ sha256_high_sierra }}" => :high_sierra
  #  end
""")

def main():
    """ Driver for building sqlcmd.rb formula"""
    print('Generate formula for SQLCMD Tools homebrew release.')

    upstream_url = os.environ['HOMEBREW_UPSTREAM_URL']
    bottle_url = os.getenv('HOMEBREW_BOTTLE_URL', None)

    print('HOMEBREW_UPSTREAM_URL:: ' + upstream_url)

    # -- determine if upstream is a local file or remote URL --
    if not upstream_url.startswith('http'):
        local_src = os.path.join(
            os.path.dirname(__file__),
            os.path.basename(upstream_url)
        )

        if os.path.isfile(local_src):
            upstream_url = 'file://{{PWD}}/' + os.path.basename(upstream_url)
            upstream_sha = compute_sha256(local_src)
        else:
            raise FileNotFoundError(local_src)
    else:
        upstream_sha = compute_sha256(upstream_url)

    template_path = os.path.join(os.path.dirname(__file__), TEMPLATE_FILE_NAME)
    with open(template_path, mode='r') as fq:
        template_content = fq.read()

    template = jinja2.Template(template_content)

    content = template.render(
        cli_version=os.environ['CLI_VERSION'],
        upstream_url=upstream_url,
        upstream_sha=upstream_sha,
        resources=collect_resources(),
        bottle_hash=last_bottle_hash(bottle_url)
    )

    content = content + '\n' if not content.endswith('\n') else content

    with open('sqlcmd.rb', mode='w') as fq:
        fq.write(content)

def compute_sha256(resource: str) -> str:
    import hashlib
    sha256 = hashlib.sha256()

    if os.path.isfile(resource):
        with open(resource, 'rb') as f:
            for byte_block in iter(lambda: f.read(4096), b""):
                sha256.update(byte_block)
    else:
        resp = requests.get(resource)
        resp.raise_for_status()
        sha256.update(resp.content)

    return sha256.hexdigest()

def collect_resources() -> str:
    nodes_render = []
    for node in make_graph():
        nodes_render.append(RESOURCE_TEMPLATE.render(resource=node))
    return '\n\n'.join(nodes_render)

def make_graph() -> list:
    """
    Builds the dependency graph.
    """
    dependencies = []

    # TODO

    print('Total dependencies: {0}'.format(len(dependencies)))

    return dependencies

def last_bottle_hash(resource_url: str) -> str:
    """
    Fetch the `bottle do` and end from the latest brew formula
    """
    # if no existing binary bottle supplied then build commented bottle section
    # as a helper to be populated in later
    if not resource_url:
        return COMMENTED_BOTTLE_TEMPLATE.render()

    # -- else extract  bottle hash and reuse --
    resp = requests.get(resource_url)
    resp.raise_for_status()

    lines = resp.text.split('\n')
    look_for_end = False
    start = 0
    end = 0
    for idx, content in enumerate(lines):
        if look_for_end:
            if 'end' in content:
                end = idx
                break
        else:
            if 'bottle do' in content:
                start = idx
                look_for_end = True

    return '\n'.join(lines[start: end + 1])

if __name__ == '__main__':
    main()
