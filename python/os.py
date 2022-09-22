#!/usr/bin/env python3
import sys
import argparse
import base64
import lxml.etree as et
import requests
from collections import namedtuple
from urllib.parse import unquote, quote


data_types = [
    "conditionals",
    "dictionaries",
    "linkage",
    "notes",
    "original",
    "outlines",
    "sources",
    "styles",
    "transliteration"
]

server_port = namedtuple("server_port", ["protocol", "host", "port"])
server_location = {
    "dev": server_port(protocol="https", host="db-dev.jewishliturgy.org", port=443),
    "feature": server_port(protocol="https", host="db-feature.jewishliturgy.org", port=443),
    "local": server_port(protocol="http", host="localhost", port=5000),
    "prod": server_port(protocol="https", host="db-prod.jewishliturgy.org", port=443),
}
def server_url(server):
    coords = server_location[server]
    return f"{coords.protocol}://{coords.host}:{coords.port}"

namespaces = {
    "html": "http://www.w3.org/1999/xhtml",
    "a": "http://jewishliturgy.org/ns/access/1.0"
}


def auth_headers(args):
    return ({
        "Authorization": ("Basic " + base64.b64encode((args.user + ":" + args.password).encode("utf8")).decode())
    } if args.user and args.password
            else {})


search_result = namedtuple("search_result", ["title", "resource", "href"])

def paginate(request_url, request_size=100, params=None, headers=None):
    """ paginate results from a search-type request URL, return one list element at a time, until there are none left """
    if params is None:
        params = {}
    if headers is None:
        headers = {}
    finished = False
    start_index = 1
    max_results = request_size
    while not finished:
        data = requests.get(request_url, params={
            "start": start_index,
            "max_results": max_results,
            **params
        }, headers=headers)
        if data.status_code != 200:
            raise(RuntimeError(f"{data.status_code} {data.reason}"))
        xml = et.fromstring(data.content)
        start_index = int(xml.xpath("html:head/html:meta[@name='startIndex']/@content", namespaces=namespaces)[0])
        items_per_page = int(xml.xpath("html:head/html:meta[@name='itemsPerPage']/@content", namespaces=namespaces)[0])
        total_results = int(xml.xpath("html:head/html:meta[@name='totalResults']/@content", namespaces=namespaces)[0])

        for result in xml.xpath("html:body/html:*/html:li/html:a[@class='document']", namespaces=namespaces):
            href = result.attrib["href"]
            resource = unquote(href.split("/")[-1])
            yield search_result(title=result.text, resource=resource, href=href)

        start_index += items_per_page
        finished = start_index >= total_results

def up(args):
    try:
        response = requests.get(server_url(args.server), timeout=args.timeout)
        is_up = response.status_code == 200
    except requests.exceptions.RequestException:
        is_up = False

    if is_up:
        print("Up")
    else:
        print("Down")
    return 0 if is_up else 1

def ls(args):
    """ List or query database resources """
    ctr = -1
    for ctr, result in enumerate(paginate(f"{server_url(args.server)}/api/data/{args.data_type}", 500,
                                          {"q": quote(args.query)} if args.query else {},
                                          headers=auth_headers(args))):
        print(f"{result.resource}\t{result.title}")
    print(f"{ctr + 1} results found.")
    return 0


def get(args):
    request_url = f"{server_url(args.server)}/api/data/{args.data_type}/{args.resource}"
    headers = {
        **auth_headers(args),
    }

    data = requests.get(request_url, headers=headers)
    if data.status_code == 200:
        with (open(args.output, "w") if args.output else sys.stdout) as f:
            f.write(data.content.decode("utf8"))
    else:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    return 0

def post(args):
    request_url = f"{server_url(args.server)}/api/data/{args.data_type}"
    headers = {
        **auth_headers(args),
        "Content-type": "application/xml"
    }

    with (open(args.file, "r") if args.file else sys.stdin) as f:
        data = requests.post(request_url, f.read(), headers=headers)
    if data.status_code < 300:
        print(f"{data.status_code} {data.reason}")
    else:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    return 0

def put(args):
    request_url = f"{server_url(args.server)}/api/data/{args.data_type}/{args.resource}"
    headers = {
        **auth_headers(args),
        "Content-type": "application/xml"
    }

    with (open(args.file, "r") if args.file else sys.stdin) as f:
        data = requests.put(request_url, f.read(), headers=headers)
    if data.status_code < 300:
        print(f"{data.status_code} {data.reason}")
    else:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    return 0

def rm(args):
    request_url = f"{server_url(args.server)}/api/data/{args.data_type}/{args.resource}"
    headers = {
        **auth_headers(args)
    }


    data = requests.delete(request_url, headers=headers)
    if data.status_code < 300:
        print(f"{data.status_code} {data.reason}")
    else:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    return 0


def combine(args):
    request_url = (
            f"{server_url(args.server)}/api/data/original/{args.resource}/combined"
    )
    html_header = {"Accept": "application/xhtml+xml"} if args.html else {}
    headers = {
        **auth_headers(args),
        **html_header
    }

    params = {
        **({"transclude": "true"} if args.subparser == "transclude" else {})
    }
    data = requests.get(request_url, params=params, headers=headers)
    if data.status_code == 200:
        with (open(args.output, "w") if args.output else sys.stdout) as f:
            f.write(data.content.decode("utf8"))
    else:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    return 0

def validate(args):
    request_url = (f"{server_url(args.server)}/api/data/{args.data_type}" + (
        f"/{args.resource}" if args.resource else ""))
    headers = {
        **auth_headers(args),
        "Content-type": "application/xml",
    }
    params = {
        "validate": "true"
    }
    request = requests.put if args.resource else requests.post
    with (open(args.file, "r") if args.file else sys.stdin) as f:
        data = request(request_url, f.read(), params=params, headers=headers)
    is_valid = False
    if data.status_code == 200:
        xml = et.fromstring(data.content)
        is_valid = xml.xpath("status='valid'", namespaces=namespaces)
        print(data.content.decode("utf8"))
        print("Valid" if is_valid else "Invalid")
    else:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    return 0 if is_valid else 1

def access(args):
    request_url = f"{server_url(args.server)}/api/data/{args.data_type}/{args.resource}/access"
    headers = {
        **auth_headers(args),
        "Content-type": "application/xml",
    }
    data = requests.get(request_url, headers=headers)
    if data.status_code == 200:
        xml = et.fromstring(data.content)
        you = args.user or "guest"
        you_read = "r" if xml.xpath("a:you/@read='true'", namespaces=namespaces) else "-"
        you_write = "w" if xml.xpath("a:you/@write='true'", namespaces=namespaces) else "-"
        you_chmod = "m" if xml.xpath("a:you/@chmod='true'", namespaces=namespaces) else "-"
        you_relicense = "l" if xml.xpath("a:you/@relicense='true'", namespaces=namespaces) else "-"

        owner = xml.xpath("string(a:owner)", namespaces=namespaces)
        group = xml.xpath("string(a:group)", namespaces=namespaces)
        group_write = "w" if xml.xpath("a:group/@write = 'true'", namespaces=namespaces) else "-"

        world_read = "r" if xml.xpath("a:world/@read = 'true'", namespaces=namespaces) else "-"
        world_write = "w" if xml.xpath("a:world/@write = 'true'", namespaces=namespaces) else "-"
        print(f"{you}:{you_read}{you_write}{you_chmod}{you_relicense} {owner} {group}({group_write}) {world_read}{world_write}")
    else:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    return 0

def transliterate(args):
    request_url = f"{server_url(args.server)}/api/utility/translit/{args.table}"
    headers = {
        **auth_headers(args),
        "Content-type": "text/plain" if args.text else "application/xml",
        "Accept": "text/plain" if args.text else "application/xml",
    }
    with (open(args.file, "r") if args.file else sys.stdin) as f:
        data = requests.post(request_url, f.read().encode("utf8"), headers=headers)
        print(data.request.url)
        print(data.request.body)
        print(data.request.headers)

    if data.status_code == 200:
        with (open(args.output, "w") if args.output else sys.stdout) as f:
            f.write(data.content.decode("utf8"))
    else:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    return 0

def main():
    ap = argparse.ArgumentParser()
    authentication_group = ap.add_argument_group()
    authentication_group.add_argument("--user", action="store", help="user name", default=None)
    authentication_group.add_argument("--password", action="store", help="password", default=None)

    server_type_group = ap.add_mutually_exclusive_group()
    server_type_group.add_argument("--dev", action="store_const", dest="server", const="dev",
                                   help="Use development server (default)", default="dev")
    server_type_group.add_argument("--feature", action="store_const", dest="server", const="feature",
                                   help="Use feature server")
    server_type_group.add_argument("--local", action="store_const", dest="server", const="local",
                                   help="Use local server")
    server_type_group.add_argument("--prod", action="store_const", dest="server", const="prod",
                                   help="Use production server")

    command_parsers = ap.add_subparsers(title="command", dest="subparser", description="Available commands")
    up_parser = command_parsers.add_parser("up", description="Check if the server is responding")
    up_parser.add_argument("--timeout", action="store", dest="timeout", type=float, default=10.0,
                           help="Time in seconds to wait for a response")
    up_parser.set_defaults(func=up)

    data_type_for = lambda subparser: subparser.add_argument("data_type", action="store", type=str,
                                                             choices=data_types,
                                                             help="Type of resource")
    resource_for = lambda subparser: subparser.add_argument("resource", action="store", type=str,
                                                            help="Name of database resource")
    file_for = lambda subparser: subparser.add_argument("file", action="store", type=str, nargs="?", default=None,
                                                        help="File containing data to post (default: stdin)")
    output_for = lambda subparser: subparser.add_argument("--output", action="store", dest="output",
                                                          help="Output file (default: stdout)")

    ls_parser = command_parsers.add_parser("ls", aliases=["search"], description="list resources or search the database")
    data_type_for(ls_parser)
    ls_parser.add_argument("--query", dest="query", help="Search text (must be quoted if it has whitespace)")
    ls_parser.set_defaults(func=ls)

    get_parser = command_parsers.add_parser("get", description="get the content of a resource")
    data_type_for(get_parser)
    resource_for(get_parser)
    output_for(get_parser)
    get_parser.set_defaults(func=get)

    post_parser = command_parsers.add_parser("post", description="Post a new resource of the given data type")
    data_type_for(post_parser)
    file_for(post_parser)
    post_parser.set_defaults(func=post)

    put_parser = command_parsers.add_parser("put", description="Overwrite the content of the given resource")
    data_type_for(put_parser)
    resource_for(put_parser)
    file_for(put_parser)
    put_parser.set_defaults(func=put)

    delete_parser = command_parsers.add_parser("delete", aliases=["rm"], help="Remove a resource from the database")
    data_type_for(delete_parser)
    resource_for(delete_parser)
    delete_parser.set_defaults(func=rm)

    combine_parser = command_parsers.add_parser("combine", aliases=["transclude"],
                                                help="Retrieve a resource with combined overlapping XML hierarchies "
                                                     "(or transcluded to include all included data from other resources)")
    resource_for(combine_parser)
    combine_parser.add_argument("--html", action="store_true", dest="html", default=False, help="Output in HTML")
    output_for(combine_parser)
    combine_parser.set_defaults(func=combine)

    validate_parser = command_parsers.add_parser("validate", description="Validate JLPTEI")
    data_type_for(validate_parser)
    resource_for(validate_parser)
    file_for(validate_parser)
    validate_parser.set_defaults(func=validate)

    access_parser = command_parsers.add_parser("access", description="Determine access constraints on a resource.\n"
                                               "Output format: <you>:<perms> <owner> <group>(<perms>) <world perms>\n"
                                               "Permissions are:\n"
                                               "r - read\n"
                                               "w - write\n"
                                               "m - chmod (change permissions)\n"
                                               "l - change license",
                                               formatter_class=argparse.RawTextHelpFormatter)
    data_type_for(access_parser)
    resource_for(access_parser)
    access_parser.set_defaults(func=access)

    transliterate_parser = command_parsers.add_parser("transliterate", description="Transliterate text")
    transliterate_parser.add_argument("table", help="transliteration table")
    file_for(transliterate_parser)
    output_for(transliterate_parser)
    transliterate_parser.add_argument("--text", action="store_true", default=False,
                                      help="treat the input data as text instead of XML")
    transliterate_parser.set_defaults(func=transliterate)

    args = ap.parse_args()
    return args.func(args)

if __name__ == "__main__":
    sys.exit(main())