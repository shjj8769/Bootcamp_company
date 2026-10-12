import base64
import hashlib
import hmac
import json
import os
import time

from dotenv import load_dotenv
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

load_dotenv()

# 직원 정보는 Firestore main_server 컬렉션(문서 ID = e_id)이 기준
EMPLOYEE_COLLECTION = 'main_server'

# 부서(e_team)가 이 값이면 대리점 직원, 그 외는 본사 직원
STORE_TEAM = '대리점'

# 직급 순서: 결재는 사원 -> 팀장 -> 임원(이사) 순으로 진행
JOB_RANK = {'사원': 1, '팀장': 2, '이사': 3}

# 토큰 서명 키 (.env의 AUTH_SECRET 사용), 만료 시간(초)
AUTH_SECRET = os.getenv('AUTH_SECRET', 'dev-secret-change-me')
TOKEN_EXPIRE_SECONDS = 60 * 60 * 8

bearer = HTTPBearer(auto_error=False)

_db = None


def get_db():
    global _db
    if _db is None:
        _db = firestore.Client(project=os.getenv('FIREBASE_PROJECT_ID'))
    return _db


# e_id로 직원 1명 조회 (없으면 None)
def get_employee(e_id: str):
    doc = get_db().collection(EMPLOYEE_COLLECTION).document(e_id).get()
    return doc.to_dict() if doc.exists else None


def is_store_team(e_team):
    return e_team == STORE_TEAM


# 더미 데이터라서 평문 비교. 해시로 바꿀 때는 이 함수만 수정
def verify_password(input_password, stored_password):
    if not stored_password:
        return False
    return hmac.compare_digest(str(input_password), str(stored_password))


def _b64(data: bytes):
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()


def _unb64(text: str):
    return base64.urlsafe_b64decode(text + '=' * (-len(text) % 4))


def _sign(body: str):
    return _b64(hmac.new(AUTH_SECRET.encode(), body.encode(), hashlib.sha256).digest())


def make_token(payload: dict):
    payload = {**payload, 'exp': int(time.time()) + TOKEN_EXPIRE_SECONDS}
    body = _b64(json.dumps(payload, separators=(',', ':')).encode())
    return body + '.' + _sign(body)


def read_token(token: str):
    try:
        body, sig = token.split('.')
        if not hmac.compare_digest(sig, _sign(body)):
            raise ValueError('bad signature')
        payload = json.loads(_unb64(body))
        if payload['exp'] < time.time():
            raise ValueError('expired')
        return payload
    except Exception:
        raise HTTPException(status_code=401, detail='invalid token')


# 요청 헤더(Authorization: Bearer <token>)의 토큰으로 로그인한 직원 정보를 가져옴
def get_current_employee(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)):
    if credentials is None:
        raise HTTPException(status_code=401, detail='login required')
    return read_token(credentials.credentials)


# 본사 직원 전용 / 대리점 직원 전용 API에 Depends로 사용
def require_hq(employee: dict = Depends(get_current_employee)):
    if employee['kind'] != 'hq':
        raise HTTPException(status_code=403, detail='hq only')
    return employee


def require_store(employee: dict = Depends(get_current_employee)):
    if employee['kind'] != 'store':
        raise HTTPException(status_code=403, detail='store only')
    return employee


def job_rank(e_jobtitle):
    return JOB_RANK.get(e_jobtitle, 0)


# 결재 권한: 같은 부서이고 신청자보다 직급이 높아야 함
def can_approve(approver: dict, requester: dict):
    return (
        approver['e_team'] == requester['e_team']
        and job_rank(approver['e_jobtitle']) > job_rank(requester['e_jobtitle'])
    )


# 신청자 기준 결재 라인: 같은 부서에서 신청자보다 높은 직급을 낮은 순서대로 반환
# 해당 직급의 직원이 없는 단계(예: 임원 없는 부서)는 건너뜀
def approval_line(requester: dict):
    team_docs = (
        get_db().collection(EMPLOYEE_COLLECTION)
        .where(filter=FieldFilter('e_team', '==', requester['e_team']))
        .stream()
    )
    steps = {}
    my_rank = job_rank(requester['e_jobtitle'])
    for row in sorted((doc.to_dict() for doc in team_docs), key=lambda r: r['e_id']):
        rank = job_rank(row['e_jobtitle'])
        if rank > my_rank:
            steps.setdefault(rank, {'e_jobtitle': row['e_jobtitle'], 'approvers': []})
            steps[rank]['approvers'].append(row['e_id'])
    return [
        {'step': no, **steps[rank]}
        for no, rank in enumerate(sorted(steps), start=1)
    ]
