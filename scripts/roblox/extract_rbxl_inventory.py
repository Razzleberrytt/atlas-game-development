#!/usr/bin/env python3
"""Loss-minimizing Roblox binary-place inventory/script extractor. Requires lz4.

This intentionally extracts script source plus hierarchy/identity for reconciliation; it is not a property-perfect Roblox serializer.
"""
from pathlib import Path
import struct, json, hashlib
import lz4.block

import argparse
ap=argparse.ArgumentParser()
ap.add_argument('place')
ap.add_argument('--out', default='rbxl_inventory.json')
args=ap.parse_args()
PATH=Path(args.place)
b=PATH.read_bytes()
assert b[:14] == b'<roblox!\x89\xff\r\n\x1a\n'
version=struct.unpack_from('<H',b,14)[0]
class_count, inst_count = struct.unpack_from('<II',b,16)
print('version',version,'classes',class_count,'instances',inst_count)

def u32(data,o): return struct.unpack_from('<I',data,o)[0]
def i32(data,o): return struct.unpack_from('<i',data,o)[0]
def read_string(data,o):
    n=u32(data,o); o+=4
    s=data[o:o+n]; return s,o+n

def deint_u32_be(data,n):
    assert len(data)>=n*4
    out=[]
    for i in range(n):
        x=(data[i]<<24)|(data[n+i]<<16)|(data[2*n+i]<<8)|data[3*n+i]
        out.append(x)
    return out

def zigzag32(x):
    return (x>>1) ^ -(x&1)

def refs(data,o,n):
    raw=deint_u32_be(data[o:o+4*n],n); o += 4*n
    diffs=[zigzag32(x) for x in raw]
    vals=[]; prev=0
    for d in diffs:
        v=prev+d; vals.append(v); prev=v
    return vals,o

chunks=[]; off=32
while off+16<=len(b):
    sig=b[off:off+4].rstrip(b'\x00').decode('ascii','replace')
    clen,ulen=struct.unpack_from('<II',b,off+4)
    payload_off=off+16
    raw=b[payload_off:payload_off+(clen if clen else ulen)]
    if clen:
        data=lz4.block.decompress(raw,uncompressed_size=ulen)
    else:
        data=raw
    if len(data)!=ulen:
        raise ValueError(f'length mismatch for {sig}: {len(data)} != {ulen}')
    chunks.append((sig,data,off,clen,ulen))
    off=payload_off+(clen if clen else ulen)
    if sig=='END': break

classes={}; class_by_inst={}
for sig,data,*_ in chunks:
    if sig!='INST': continue
    o=0; cid=i32(data,o); o+=4
    cn,o=read_string(data,o); cn=cn.decode('utf-8','replace')
    hs=data[o]; o+=1; n=u32(data,o); o+=4
    r,o=refs(data,o,n)
    svc=list(data[o:o+n]) if hs else []
    classes[cid]={'name':cn,'ids':r,'has_service':bool(hs),'service':svc}
    for rid in r: class_by_inst[rid]=cn

shared=[]
for sig,data,*_ in chunks:
    if sig=='SSTR':
        o=0; _ver=i32(data,o);o+=4; n=u32(data,o);o+=4
        for _ in range(n):
            o+=16; s,o=read_string(data,o); shared.append(s)

props={}
script_classes={'Script','LocalScript','ModuleScript'}
selected_names={'Name','Source','Disabled','Enabled','RunContext','LinkedSource','ScriptGuid'}
for sig,data,*_ in chunks:
    if sig!='PROP': continue
    o=0; cid=i32(data,o);o+=4
    pn,o=read_string(data,o); pn=pn.decode('utf-8','replace')
    typ=data[o];o+=1
    c=classes.get(cid)
    if not c: continue
    n=len(c['ids'])
    if not ((pn=='Name') or (c['name'] in script_classes and pn in selected_names)): continue
    vals=None
    if typ==0x01:
        vals=[]
        for _ in range(n):
            s,o=read_string(data,o); vals.append(s.decode('utf-8','replace'))
    elif typ==0x02:
        vals=[bool(x) for x in data[o:o+n]]; o+=n
    elif typ==0x12:
        vals=deint_u32_be(data[o:o+4*n],n);o+=4*n
    elif typ==0x1C:
        idxs=deint_u32_be(data[o:o+4*n],n);o+=4*n
        vals=[shared[i].decode('utf-8','replace') if 0<=i<len(shared) else f'<SSTR:{i}>' for i in idxs]
    else:
        vals=[f'<type {typ:#x} not decoded>']*n
    for rid,val in zip(c['ids'],vals): props.setdefault(rid,{})[pn]=val

parent={}
for sig,data,*_ in chunks:
    if sig=='PRNT':
        o=1; n=u32(data,o);o+=4
        ch,o=refs(data,o,n); pa,o=refs(data,o,n)
        parent.update(zip(ch,pa))

names={rid:props.get(rid,{}).get('Name',class_by_inst.get(rid,'?')) for rid in class_by_inst}
def path_for(rid):
    seg=[]; seen=set(); cur=rid
    while cur!=-1 and cur in class_by_inst and cur not in seen:
        seen.add(cur); seg.append(names.get(cur,class_by_inst[cur])); cur=parent.get(cur,-1)
    return '/'.join(reversed(seg))

scripts=[]
for rid,cn in class_by_inst.items():
    if cn in script_classes:
        p=props.get(rid,{})
        src=p.get('Source','')
        scripts.append({'id':rid,'class':cn,'name':names.get(rid),'path':path_for(rid),'disabled':p.get('Disabled'),'enabled':p.get('Enabled'),'run_context':p.get('RunContext'),'source_len':len(src) if isinstance(src,str) else None,'source_sha256':hashlib.sha256(src.encode()).hexdigest() if isinstance(src,str) else None,'source':src})

out={'metadata':{'file':PATH.name,'size':len(b),'sha256':hashlib.sha256(b).hexdigest(),'version':version,'class_count':class_count,'instance_count':inst_count},'classes':[{**{'class_id':cid},**c} for cid,c in sorted(classes.items())],'scripts':scripts,'roots':[{'id':rid,'class':class_by_inst[rid],'name':names[rid],'path':path_for(rid)} for rid in class_by_inst if parent.get(rid,-1)==-1],'instances':[{'id':rid,'class':cn,'name':names[rid],'parent_id':parent.get(rid,-1),'path':path_for(rid)} for rid,cn in class_by_inst.items()]}
Path(args.out).write_text(json.dumps(out,indent=2,ensure_ascii=False)+'\n')
print(f'wrote {args.out}: {len(out["scripts"])} scripts, {len(out["instances"])} instances')
