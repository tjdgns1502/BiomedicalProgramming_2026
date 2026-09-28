"""Project execution and event records. Statistical judgment is reviewed separately."""
from pathlib import Path
import argparse, datetime, hashlib, json, os, subprocess, sys

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT.parent
R=Path('C:/Program Files/R/R-4.6.1/bin/Rscript.exe')
def stamp():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def write(path,obj):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def event(kind,task,body,**extra):
    p=ROOT/'memory/events.jsonl';p.parent.mkdir(parents=True,exist_ok=True)
    item=dict(timestamp=stamp(),event_id=os.urandom(8).hex(),task_id=task,kind=kind,body=body,**extra)
    with p.open('a',encoding='utf-8') as f:f.write(json.dumps(item,ensure_ascii=False)+'\n')
    return item
def execute(task,script,args=()):
    run_id=task+'-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out=ROOT/'runs'/run_id;out.mkdir(parents=True,exist_ok=False)
    # Relative ASCII analysis paths avoid R locale conversion of Korean CLI paths.
    args=[a.replace('{run_dir}',out.relative_to(WORK).as_posix()) for a in args]
    cmd=[str(R),'--vanilla',str((WORK/script).resolve()),*args]
    metadata=dict(task_id=task,run_id=run_id,started=stamp(),command=cmd,cwd=str(WORK),
        script_sha256=sha(WORK/script),plan_sha256=sha(ROOT/'config/analysis_plan.json'),status='running',
        source_hashes={str(p.relative_to(WORK)):sha(p) for p in (ROOT/'src').glob('*.R')},
        config_hashes={str(p.relative_to(WORK)):sha(p) for p in (ROOT/'config').glob('*.json')},
        input_hashes={a:sha(WORK/a) for a in args if (WORK/a).is_file()})
    write(out/'execution.json',metadata);event('RUN_STARTED',task,run_id,command=cmd)
    env=os.environ.copy();env.update(LANG='C',LC_ALL='C')
    with (out/'stdout.log').open('wb') as so,(out/'stderr.log').open('wb') as se:
        proc=subprocess.run(cmd,cwd=WORK,env=env,stdout=so,stderr=se)
    metadata.update(finished=stamp(),exit_code=proc.returncode,status='submitted' if proc.returncode==0 else 'failed')
    write(out/'execution.json',metadata);event('RUN_FINISHED',task,run_id,exit_code=proc.returncode)
    print(json.dumps(metadata,ensure_ascii=False,indent=2));return proc.returncode
def environment():
    env=os.environ.copy();env.update(LANG='C',LC_ALL='C')
    cmd=[str(R),'--vanilla','-e','sessionInfo(); cat("\\nPACKAGES\\n"); p<-installed.packages(); print(p[,c("Package","Version")])']
    proc=subprocess.run(cmd,env=env,capture_output=True)
    out=ROOT/'runs/E00-environment';out.mkdir(parents=True,exist_ok=True)
    (out/'session-info.txt').write_bytes(proc.stdout)
    (out/'stderr.log').write_bytes(proc.stderr)
    write(ROOT/'config/environment.json',dict(rscript=str(R),command=cmd,exit_code=proc.returncode,
        locale_override='C, process only',workspace=str(WORK),captured_at=stamp(),
        session_info='runs/E00-environment/session-info.txt',python=sys.version))
    event('ENVIRONMENT_CHECKED','E00','R environment captured',exit_code=proc.returncode)
    print(proc.stdout.decode('utf-8',errors='replace')[:1600]);return proc.returncode
if __name__=='__main__':
    p=argparse.ArgumentParser();s=p.add_subparsers(dest='cmd',required=True)
    s.add_parser('environment');s.add_parser('status')
    a=s.add_parser('run');a.add_argument('task');a.add_argument('script');a.add_argument('args',nargs=argparse.REMAINDER)
    a=s.add_parser('event');a.add_argument('kind');a.add_argument('task');a.add_argument('body')
    args=p.parse_args()
    if args.cmd=='environment':sys.exit(environment())
    elif args.cmd=='run':sys.exit(execute(args.task,args.script,args.args))
    elif args.cmd=='event':print(json.dumps(event(args.kind,args.task,args.body),ensure_ascii=False))
    else:
        for f in sorted((ROOT/'runs').glob('*/execution.json')):print(f.read_text(encoding='utf-8'))
        p=ROOT/'memory/progress.md'
        if p.exists():print(p.read_text(encoding='utf-8'))
