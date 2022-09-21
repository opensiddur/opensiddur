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
    "html": "http://www.w3.org/1999/xhtml"
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



def ls(args):
    """ List or query database resources """
    ctr = -1
    for ctr, result in enumerate(paginate(f"{server_url(args.server)}/api/data/{args.data_type}", 500,
                                          {"q": quote(args.query)} if args.query else {},
                                          headers=auth_headers(args))):
        print(f"{result.resource}\t{result.title}")
    print(f"{ctr + 1} results found.")


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
    if data.status_code == 200:
        print(data.content.decode("utf8"))
    else:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")


def main():
    ap = argparse.ArgumentParser()
    authentication_group = ap.add_argument_group()
    authentication_group.add_argument("--user", action="store", help="user name", default=None)
    authentication_group.add_argument("--password", action="store", help="password", default=None)

    server_type_group = ap.add_mutually_exclusive_group()
    server_type_group.add_argument("--dev", action="store_const", dest="server", const="dev",
                                   help="Use dev server (default)", default="dev")
    server_type_group.add_argument("--feature", action="store_const", dest="server", const="feature",
                                   help="Use feature server")
    server_type_group.add_argument("--local", action="store_const", dest="server", const="local",
                                   help="Use local server")
    server_type_group.add_argument("--prod", action="store_const", dest="server", const="prod",
                                   help="Use production server")

    command_parsers = ap.add_subparsers(title="command", dest="subparser")
    ls_parser = command_parsers.add_parser("ls", aliases=["search"])
    ls_parser.add_argument("data_type", action="store", type=str,
                    choices=data_types)
    ls_parser.add_argument("--query", dest="query", help="Search text")
    ls_parser.set_defaults(func=ls)

    get_parser = command_parsers.add_parser("get")
    get_parser.add_argument("data_type", action="store", type=str, choices=data_types)
    get_parser.add_argument("resource", action="store", type=str)
    get_parser.add_argument("--output", action="store", dest="output")

    combine_parser = command_parsers.add_parser("combine", aliases=["transclude"])
    combine_parser.add_argument("resource", action="store", type=str)
    combine_parser.add_argument("--html", action="store_true", dest="html", default=False)
    combine_parser.add_argument("--output", action="store", dest="output")
    combine_parser.set_defaults(func=combine)

    validate_parser = command_parsers.add_parser("validate")
    validate_parser.add_argument("data_type", action="store", type=str, choices=data_types)
    validate_parser.add_argument("--resource", action="store", type=str, required=False)
    validate_parser.add_argument("--file", action="store", type=str, required=False)
    validate_parser.set_defaults(func=validate)

    args = ap.parse_args()
    args.func(args)

if __name__ == "__main__":
    main()