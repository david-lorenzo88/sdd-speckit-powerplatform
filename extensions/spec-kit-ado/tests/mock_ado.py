"""Minimal mock of the Azure DevOps work item REST API (Agile rules) for testing ado-sync.ps1."""
import json, re, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs, unquote

ITEMS = {}
NEXT = [100]
LOG = []
# Strict transitions to exercise the fallback path (New -> Resolved is rejected).
ALLOWED = {
    'Task': {'New': {'Active', 'Closed', 'Removed'}, 'Active': {'New', 'Closed', 'Removed'}, 'Closed': {'Active', 'New'}, 'Removed': {'New'}},
    'User Story': {'New': {'Active', 'Closed', 'Removed'}, 'Active': {'New', 'Resolved', 'Closed', 'Removed'},
                   'Resolved': {'Active', 'Closed'}, 'Closed': {'Active', 'Resolved'}, 'Removed': {'New'}},
    'Feature': {'New': {'Active', 'Closed', 'Removed'}, 'Active': {'New', 'Resolved', 'Closed', 'Removed'},
                'Resolved': {'Active', 'Closed'}, 'Closed': {'Active', 'Resolved'}, 'Removed': {'New'}},
}


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def send(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header('Content-Type', 'application/json'); self.end_headers(); self.wfile.write(b)

    def body(self):
        n = int(self.headers.get('Content-Length', 0))
        raw = self.rfile.read(n)
        assert self.headers.get('Content-Type', '').startswith('application/json-patch+json'), self.headers.get('Content-Type')
        ops = json.loads(raw.decode('utf-8'))
        assert isinstance(ops, list), 'body must be a JSON array'
        return ops

    def do_GET(self):
        u = urlparse(self.path); q = parse_qs(u.query)
        if self.path == '/__dump':
            return self.send(200, {'items': ITEMS, 'log': LOG})
        if '/_apis/projects/' in u.path:
            return self.send(200, {'name': unquote(u.path.split('/')[-1]), 'capabilities': {'processTemplate': {'templateName': 'Agile'}}})
        if u.path.endswith('/_apis/wit/workitems'):
            ids = [int(x) for x in q['ids'][0].split(',')]
            LOG.append(('GET', ids))
            return self.send(200, {'value': [({'id': i, 'fields': {'System.State': ITEMS[i]['fields']['System.State'], 'System.Title': ITEMS[i]['fields']['System.Title']}} if i in ITEMS else None) for i in ids]})
        self.send(404, {'message': 'not found ' + self.path})

    def do_POST(self):
        m = re.search(r'/_apis/wit/workitems/\$(.+)$', urlparse(self.path).path)
        wtype = unquote(m.group(1))
        ops = self.body()
        fields = {'System.State': 'New', 'System.WorkItemType': wtype}
        parent = None
        for op in ops:
            if op['path'].startswith('/fields/'):
                fields[op['path'][8:]] = op['value']
            elif op['path'] == '/relations/-':
                assert op['value']['rel'] == 'System.LinkTypes.Hierarchy-Reverse'
                parent = int(op['value']['url'].rsplit('/', 1)[1])
        i = NEXT[0]; NEXT[0] += 1
        ITEMS[i] = {'fields': fields, 'parent': parent}
        LOG.append(('POST', wtype, i))
        self.send(200, {'id': i})

    def do_PATCH(self):
        i = int(re.search(r'/workitems/(\d+)', self.path).group(1))
        ops = self.body()
        it = ITEMS[i]
        for op in ops:
            f = op['path'][8:]
            if f == 'System.State':
                cur, new = it['fields']['System.State'], op['value']
                if new not in ALLOWED[it['fields']['System.WorkItemType']].get(cur, set()):
                    LOG.append(('PATCH-REJECT', i, cur, new))
                    return self.send(400, {'message': f'Invalid transition {cur} -> {new}'})
            it['fields'][f] = op['value']
        LOG.append(('PATCH', i, {o['path'][8:]: o['value'] for o in ops}))
        self.send(200, {'id': i})

    def do_DELETE(self):
        i = int(re.search(r'/__delete/(\d+)', self.path).group(1))
        ITEMS.pop(i, None); self.send(200, {})


HTTPServer(('127.0.0.1', 8765), H).serve_forever()
