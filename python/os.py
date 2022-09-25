#!/usr/bin/env python3
import sys
import argparse
import base64
import getpass
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
    "local": server_port(protocol="http", host="localhost", port=3001),
    "prod": server_port(protocol="https", host="db-prod.jewishliturgy.org", port=443),
}


def server_url(server):
    coords = server_location[server]
    return f"{coords.protocol}://{coords.host}:{coords.port}"


namespaces = {
    "html": "http://www.w3.org/1999/xhtml",
    "a": "http://jewishliturgy.org/ns/access/1.0",
    "g": "http://jewishliturgy.org/ns/group/1.0",
    "status": "http://jewishliturgy.org/modules/status",
}


def auth_headers(args):
    return ({
        "Authorization": ("Basic " + base64.b64encode((args.user + ":" + args.password).encode("utf8")).decode())
    } if args.user and args.password
            else {})


search_result = namedtuple("search_result", ["title", "resource", "href"])


def paginate(request_url, request_size=100, params=None, headers=None):
    """ paginate results from a search-type request URL, return one list element at a time,
    until there are none left """
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
        print("Up", file=sys.stderr)
    else:
        print("Down", file=sys.stderr)
    return 0 if is_up else 1


def ls(args):
    """ List or query database resources """
    ctr = -1
    for ctr, result in enumerate(paginate(f"{server_url(args.server)}/api/data/{args.data_type}", 500,
                                          {"q": quote(args.query)} if args.query else {},
                                          headers=auth_headers(args))):
        print(f"{result.resource}\t{result.title}")
    print(f"{ctr + 1} results found.", file=sys.stderr)
    return 0


def get(args):
    api_path = "user" if args.subparser == "user" else f"data/{args.data_type}"
    request_url = f"{server_url(args.server)}/api/{api_path}/{args.resource}"
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
    api_path = "user" if args.subparser == "user" else f"data/{args.data_type}"
    request_url = f"{server_url(args.server)}/api/{api_path}/{args.resource}"
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
    api_path = "user" if args.subparser == "user" else f"data/{args.data_type}"
    request_url = (f"{server_url(args.server)}/api/{api_path}" + (
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
        print("Valid" if is_valid else "Invalid", file=sys.stderr)
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


def chmod(args):
    request_url = f"{server_url(args.server)}/api/data/{args.data_type}/{args.resource}/access"
    headers = {
        **auth_headers(args),
        "Content-type": "application/xml",
    }
    existing_access = requests.get(request_url, headers=headers)
    if existing_access.status_code == 200:
        xml = et.fromstring(existing_access.content)
        you_chmod = xml.xpath("a:you/@chmod='true'", namespaces=namespaces)

        if not you_chmod:
            print("Permission denied.", file=sys.stderr)
            return 1

        owner = xml.xpath("string(a:owner)", namespaces=namespaces)
        group = xml.xpath("string(a:group)", namespaces=namespaces)
        group_write = xml.xpath("a:group/@write = 'true'", namespaces=namespaces)

        world_read = xml.xpath("a:world/@read = 'true'", namespaces=namespaces)
        world_write = xml.xpath("a:world/@write = 'true'", namespaces=namespaces)

        new_owner = args.owner or owner
        new_group = args.group or group
        new_group_write = str((args.g == "w") if args.g else group_write).lower()

        new_world_read = str(("r" in args.o) if args.o else world_read).lower()
        new_world_write = str(("w" in args.o) if args.o else world_write).lower()

        new_access = f"""<a:access xmlns:a="{namespaces['a']}">
            <a:owner>{new_owner}</a:owner>
            <a:group write="{new_group_write}">{new_group}</a:group>
            <a:world read="{new_world_read}" write="{new_world_write}"/> 
        </a>"""
        response = requests.put(request_url, new_access, headers=headers)
        if response.status_code < 300:
            print("Changed.", file=sys.stderr)
        else:
            raise RuntimeError(f"{response.status_code} {response.reason} {response.content.decode('utf8')}")
    else:
        raise RuntimeError(f"{existing_access.status_code} {existing_access.reason} {existing_access.content.decode('utf8')}")
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

    if data.status_code == 200:
        with (open(args.output, "w") if args.output else sys.stdout) as f:
            f.write(data.content.decode("utf8"))
    else:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    return 0


def jobs_ls(args):
    """ List or query database resources """
    data = requests.get(f"{server_url(args.server)}/api/jobs", headers=auth_headers(args))
    if data.status_code >= 300:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    xml = et.fromstring(data.content)
    for result in xml.xpath("html:body/html:*/html:li", namespaces=namespaces):
        id = result.xpath("string(html:a/@href)", namespaces=namespaces).split("/")[-1]
        title = result.xpath("string(html:span[@class='title'])", namespaces=namespaces)
        user = result.xpath("string(html:span[@class='user'])", namespaces=namespaces)
        state = result.xpath("string(html:span[@class='state'])", namespaces=namespaces)
        started = result.xpath("string(html:span[@class='started'])", namespaces=namespaces)
        completed = result.xpath("string(html:span[@class='completed'])", namespaces=namespaces)
        print("\t".join([id, title, user, state, started, completed]))
    return 0


def jobs_status(args):
    data = requests.get(f"{server_url(args.server)}/api/jobs/{args.id}", headers={
        **auth_headers(args),
        "Content-type": "application/xml"
    })
    if data.status_code >= 300:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    xml = et.fromstring(data.content)

    user = xml.attrib["user"]
    started = xml.attrib["started"]
    state = xml.attrib["state"]
    completed = xml.attrib.get("completed",
                               xml.attrib.get("failed", "*"))
    resource = unquote(xml.attrib["resource"]).split("/")[-1]

    print(f"{resource} by {user}: {state} at {started}-{completed}")
    for action_description in xml.xpath("*", namespaces=namespaces):
        action = et.QName(action_description).localname
        timestamp = action_description.attrib["timestamp"]
        resource = unquote(action_description.attrib["resource"]).replace("/exist/restxq/api/data/", "")
        data_type, resource_name = resource.split("/")
        stage = action_description.attrib.get("stage", "-")
        info = action_description.text or ""

        print(f"{action}:{stage}:{timestamp} {data_type} {resource_name}: {info}")


def changes(args):
    data = requests.get(f"{server_url(args.server)}/api/changes", headers=auth_headers(args))
    if data.status_code >= 300:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    xml = et.fromstring(data.content)

    for changed_file in xml.xpath("html:body/*/html:li", namespaces=namespaces):
        title = changed_file.xpath("string(html:a)", namespaces=namespaces)
        data_type, resource = unquote(changed_file.xpath("string(html:a/@href)", namespaces=namespaces)).split("/")[-2:]
        print(f"{data_type} {resource}: {title}:")
        for change in changed_file.xpath("html:ol/html:li", namespaces=namespaces):
            who = change.xpath("string(html:span[@class='who'])", namespaces=namespaces)
            change_type = change.xpath("string(html:span[@class='type'])", namespaces=namespaces)
            when = change.xpath("string(html:span[@class='when'])", namespaces=namespaces)
            message = change.xpath("string(html:span[@class='message'])", namespaces=namespaces)
            print(f"\t{change_type} by {who} at {when}: {message}")
    return 0


def login(args):
    response = requests.get(f"{server_url(args.server)}/api/login", headers={
        **auth_headers(args),
        "Accept": "application/xml"
    })
    if response.status_code >= 300:
        raise RuntimeError(f"{response.status_code} {response.reason} {response.content.decode('utf8')}")
    else:
        xml = et.fromstring(response.content)
        print(xml.text or "Not logged in.", file=sys.stderr)
    return 0


def user_ls(args):
    ctr = -1
    api = args.subparser
    for ctr, result in enumerate(paginate(f"{server_url(args.server)}/api/{api}", 500,
                                          {"q": quote(args.query)} if args.query else {},
                                          headers=auth_headers(args))):
        print(f"{result.resource}\t{result.title}")
    print(f"{ctr + 1} results found.", file=sys.stderr)
    return 0


def user_new(args):
    if not args.passwd:
        passwd = getpass.getpass()
    else:
        passwd = args.passwd
    response = requests.post(f"{server_url(args.server)}/api/user",
                             data={"user": args.name, "password": passwd},
                             headers=auth_headers(args))
    if response.status_code >= 300:
        raise RuntimeError(f"{response.status_code} {response.reason} {response.content.decode('utf8')}")
    elif response.status_code == 201:
        print("Created.", file=sys.stderr)
    else:
        print("Password changed.", file=sys.stderr)
    return 0


def user_groups(args):
    data = requests.get(f"{server_url(args.server)}/api/user/{args.resource}/groups", headers=auth_headers(args))
    if data.status_code >= 300:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    xml = et.fromstring(data.content)

    groups = []
    for group in xml.xpath("html:body/*/html:li/html:a", namespaces=namespaces):
        group_name = group.text
        is_manager = group.attrib.get("property", "") == "manager"
        groups.append(group_name + ("*" if is_manager else ""))
    print(f"{args.resource}: {', '.join(groups)}")

    return 0


def group_get(args):
    data = requests.get(f"{server_url(args.server)}/api/group/{args.resource}", headers={
        **auth_headers(args),
        "Accept": "application/xml"
    })
    if data.status_code >= 300:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    xml = et.fromstring(data.content)

    users = []
    for group in xml.xpath("//g:member", namespaces=namespaces):
        user_name = group.text
        is_manager = group.attrib.get("manager", "").lower() == "true"
        users.append(user_name + ("*" if is_manager else ""))
    print(f"{args.resource}: {', '.join(users)}")

    return 0


def user_rm(args):
    api = args.subparser
    request_url = f"{server_url(args.server)}/api/{api}/{args.resource}"
    headers = {
        **auth_headers(args)
    }

    data = requests.delete(request_url, headers=headers)
    if data.status_code < 300:
        print(f"{data.status_code} {data.reason}")
    else:
        raise RuntimeError(f"{data.status_code} {data.reason} {data.content.decode('utf8')}")
    return 0


def group_put(args):
    members = set(args.members)
    managers = set(args.managers)

    member_xml_lines = [f"""<g:member {'manager="true"' if m in managers else ""}>{m}</g:member>\n"""
                        for m in (members.union(managers))]

    group_definition = f"""<g:group xmlns:g="{namespaces['g']}">{' '.join(member_xml_lines)}</g:group>"""
    response = requests.put(f"{server_url(args.server)}/api/group/{args.resource}", group_definition,
                            headers={
                                        **auth_headers(args),
                                        "Content-type": "application/xml"
                                    })
    if response.status_code < 300:
        print(f"{response.status_code} {response.reason}")
    else:
        raise RuntimeError(f"{response.status_code} {response.reason} {response.content.decode('utf8')}")
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
                                   help="Use local server (port 3001)")
    server_type_group.add_argument("--prod", action="store_const", dest="server", const="prod",
                                   help="Use production server")

    command_parsers = ap.add_subparsers(title="command", dest="subparser", description="Available commands")
    up_parser = command_parsers.add_parser("up", help="Check if the server is responding")
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

    ls_parser = command_parsers.add_parser("ls", aliases=["search"], help="List resources or search the database")
    data_type_for(ls_parser)
    ls_parser.add_argument("--query", dest="query", help="Search text (must be quoted if it has whitespace)")
    ls_parser.set_defaults(func=ls)

    get_parser = command_parsers.add_parser("get", help="Get the content of a resource")
    data_type_for(get_parser)
    resource_for(get_parser)
    output_for(get_parser)
    get_parser.set_defaults(func=get)

    post_parser = command_parsers.add_parser("post", help="Post a new resource of the given data type")
    data_type_for(post_parser)
    file_for(post_parser)
    post_parser.set_defaults(func=post)

    put_parser = command_parsers.add_parser("put", help="Overwrite the content of the given resource")
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

    validate_parser = command_parsers.add_parser("validate", help="Validate JLPTEI")
    data_type_for(validate_parser)
    resource_for(validate_parser)
    file_for(validate_parser)
    validate_parser.set_defaults(func=validate)

    access_parser = command_parsers.add_parser("access", help="Get access constraints",
                                               description="Determine access constraints on a resource.\n"
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

    chmod_parser = command_parsers.add_parser("chmod", help="Change access for a resource")
    data_type_for(chmod_parser)
    resource_for(chmod_parser)
    chmod_parser.add_argument("--owner", action="store", default=None, help="Change owner")
    chmod_parser.add_argument("--group", action="store", default=None, help="Change group")
    chmod_parser.add_argument("-g", nargs=1, choices=["w", "-"], default=None, help="set group privileges (write)")
    chmod_parser.add_argument("-o", nargs=1, choices=["rw", "r", "w", "-"], default=None, help="set other read/write privileges")
    chmod_parser.set_defaults(func=chmod)

    transliterate_parser = command_parsers.add_parser("transliterate", help="Transliterate text")
    transliterate_parser.add_argument("table", help="transliteration table")
    file_for(transliterate_parser)
    output_for(transliterate_parser)
    transliterate_parser.add_argument("--text", action="store_true", default=False,
                                      help="treat the input data as text instead of XML")
    transliterate_parser.set_defaults(func=transliterate)

    jobs_parser = command_parsers.add_parser("jobs", help="Compilation jobs")
    jobs_parsers = jobs_parser.add_subparsers(title="jobs_commands", dest="jobs_command", description="Jobs commands")

    jobs_ls_parser = jobs_parsers.add_parser("ls", help="List jobs")
    jobs_ls_parser.set_defaults(func=jobs_ls)

    jobs_status_parser = jobs_parsers.add_parser("status", help="Get job status")
    jobs_status_parser.add_argument("id", action="store", type=str, help="Job identifier")
    jobs_status_parser.set_defaults(func=jobs_status)

    changes_parser = command_parsers.add_parser("changes", help="Show recent changes")
    changes_parser.set_defaults(func=changes)

    login_parser = command_parsers.add_parser("login", help="Check a username/password")
    login_parser.set_defaults(func=login)

    user_parser = command_parsers.add_parser("user", help="User commands")
    user_parsers = user_parser.add_subparsers(title="user_commands", dest="user_command", description="User commands")

    user_ls_parser = user_parsers.add_parser("ls", aliases=["search"], help="List or find users")
    user_ls_parser.add_argument("--query", action="store", default=None, help="Search query")
    user_ls_parser.set_defaults(func=user_ls)

    user_new_parser = user_parsers.add_parser("new", help="Sign up as a new user")
    user_new_parser.add_argument("name", action="store", help="User name")
    user_new_parser.add_argument("--passwd", dest="passwd", action="store", help="Password (may also be typed)")
    user_new_parser.set_defaults(func=user_new)

    user_passwd_parser = user_parsers.add_parser("passwd", help="Change a password")
    user_passwd_parser.add_argument("name", action="store", help="User name")
    user_passwd_parser.add_argument("--passwd", dest="passwd", action="store", help="Password (may also be typed)")
    user_passwd_parser.set_defaults(func=user_new)

    user_get = user_parsers.add_parser("get", help="Get a user or contributor profile")
    resource_for(user_get)
    output_for(user_get)
    user_get.set_defaults(func=get)

    user_put = user_parsers.add_parser("put", help="Replace a user or contributor profile")
    resource_for(user_put)
    file_for(user_put)
    user_put.set_defaults(func=put)

    user_validate = user_parsers.add_parser("validate", help="Validate a user or contributor profile")
    resource_for(user_validate)
    file_for(user_validate)
    user_validate.set_defaults(func=validate)

    user_groups_parser = user_parsers.add_parser("groups", help="List the groups a user is a member and manager* of")
    resource_for(user_groups_parser)
    user_groups_parser.set_defaults(func=user_groups)

    user_delete_parser = user_parsers.add_parser("delete", aliases=["rm"], help="Remove a user or contributor")
    resource_for(user_delete_parser)
    user_delete_parser.set_defaults(func=user_rm)

    group_parser = command_parsers.add_parser("group", help="Group commands")
    group_parsers = group_parser.add_subparsers(title="group_commands", dest="group_command",
                                                description="Group commands")

    group_ls_parser = group_parsers.add_parser("ls", aliases=["search"], help="List or find groups")
    group_ls_parser.add_argument("--query", action="store", default=None, help=argparse.SUPPRESS)
    group_ls_parser.set_defaults(func=user_ls)

    group_get_parser = group_parsers.add_parser("get", help="List users and managers* of a group")
    resource_for(group_get_parser)
    group_get_parser.set_defaults(func=group_get)

    group_new_parser = group_parsers.add_parser("new", aliases=["put"],
                                                help="Create a new group or edit an existing group, "
                                                     "setting members and managers")
    resource_for(group_new_parser)
    group_new_parser.add_argument("members", nargs="+", help="List of group members (users)")
    group_new_parser.add_argument("--managers", nargs="+", help="List of group managers (users)")
    group_new_parser.set_defaults(func=group_put)

    group_delete_parser = group_parsers.add_parser("delete", aliases=["rm"], help="Remove a group from the database")
    resource_for(group_delete_parser)
    group_delete_parser.set_defaults(func=user_rm)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
