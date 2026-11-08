#!/usr/bin/env python3
"""Opt-in presentation import from the exact packaged upstream version.

Read {local, upstream, version, distributionDescription?} on stdin. Print a
merged metainfo on stdout. The caller owns validation and writing both pins
and metadata, so a failed import cannot leave half an update on disk.
"""
import copy
import json
import sys
import xml.etree.ElementTree as ET

PRESENTATION = ('summary', 'description', 'branding', 'screenshots')


def parse(text):
    if not isinstance(text, str) or len(text) > 1024 * 1024:
        raise ValueError('metainfo must be XML no larger than 1 MiB')
    if '<!DOCTYPE' in text.upper() or '<!ENTITY' in text.upper():
        raise ValueError('DTD/entity declarations are not permitted')
    return ET.fromstring(text)


def merge(local_text, upstream_text, version, distribution_description=''):
    local, upstream = parse(local_text), parse(upstream_text)
    if local.tag != 'component' or upstream.tag != 'component':
        raise ValueError('expected component metainfo')
    if local.findtext('id') != upstream.findtext('id'):
        raise ValueError('upstream and registry component IDs differ')
    releases = upstream.findall('releases/release')
    if not releases or releases[0].get('version') != version:
        raise ValueError('upstream metainfo is not for the exact packaged version')
    description = releases[0].find('description')
    if description is None or not ''.join(description.itertext()).strip():
        raise ValueError('packaged version has no release notes')
    if upstream.find('description') is None or upstream.find('summary') is None:
        raise ValueError('upstream presentation is incomplete')
    for tag in PRESENTATION:
        source = upstream.findall(tag)
        if not source:
            continue  # Optional upstream fields do not remove registry data.
        previous = local.findall(tag)
        position = list(local).index(previous[0]) if previous else len(local)
        for node in previous:
            local.remove(node)
        for node in source:
            local.insert(position, copy.deepcopy(node))
            position += 1
    if distribution_description:
        extra = parse(distribution_description)
        if extra.tag != 'description' or any(child.tag not in ('p', 'ul', 'ol') for child in extra):
            raise ValueError('distribution prose must contain AppStream paragraphs or lists')
        local.find('description').extend(copy.deepcopy(list(extra)))
    # Only releases already known to the pin updater are eligible. Never add a
    # newer release from a moving upstream branch or guess release ordering.
    known = {node.get('version'): node for node in releases}
    for release in local.findall('releases/release'):
        source = known.get(release.get('version'))
        if source is None:
            continue
        notes = source.find('description')
        if notes is None or not ''.join(notes.itertext()).strip():
            continue
        for old in list(release):
            if old.tag == 'description' or (old.tag == 'url' and old.get('type') == 'details'):
                release.remove(old)
        for child in source:
            if child.tag == 'description' or (child.tag == 'url' and child.get('type') == 'details'):
                release.append(copy.deepcopy(child))
        if source.get('type'):
            release.set('type', source.get('type'))
        if source.get('date'):
            release.set('date', source.get('date'))
    ET.indent(local, space='  ')
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(local, encoding='unicode') + '\n'


def main():
    request = json.load(sys.stdin)
    sys.stdout.write(merge(request['local'], request['upstream'], request['version'], request.get('distributionDescription', '')))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, ET.ParseError) as error:
        sys.exit('upstream metainfo: ' + str(error))
