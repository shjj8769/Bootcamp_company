from datetime import datetime, timezone

from api_router.employee.auth_employee import JOB_RANK, approval_line, get_db, get_employee, job_rank

# 품의서(Approval) 엔티티: a_seq(PK), a_reason(품의 사유), a_name(제조사), a_items(발주 품목)
APPROVAL = 'approval'
# 품의를 올리다(Approval request form) 관계: e_id(FK), a_seq(FK), a_signatures(서명기록), a_date(처리일), a_step(결재순서), a_state(처리상태)
# 두 컬렉션 모두 문서 ID = a_seq (숫자 문자열). '_'로 시작하는 문서(_erd)는 구조 정의용이라 품의가 아님
REQUEST = 'approval_request'

# a_state: 서명이 남아 있으면 '심사중', 마지막 결재자까지 서명하면 '심사완료', 임원이 발주하면 '발주완료'
STATE_REVIEW = '심사중'
STATE_DONE = '심사완료'
STATE_ORDERED = '발주완료'

# 임원(가장 높은 직급). 결재는 사원 -> 팀장 -> 임원 순서로 하고 발주는 반드시 임원이 함
EXEC_RANK = max(JOB_RANK.values())


def now():
    return datetime.now(timezone.utc)


def real_docs(collection: str):
    return [d for d in get_db().collection(collection).stream() if not d.id.startswith('_')]


def new_cache():
    return {'employees': {}, 'lines': {}}


# 신청자(e_id)의 부서/직급은 저장하지 않고 main_server에서 가져옴
def requester_info(e_id: str, cache: dict):
    if e_id not in cache['employees']:
        row = get_employee(e_id)
        cache['employees'][e_id] = None if row is None else {
            'e_id': row['e_id'], 'e_team': row.get('e_team'), 'e_jobtitle': row.get('e_jobtitle'),
        }
    return cache['employees'][e_id]


# 신청자 기준 결재선 (사원 -> 팀장 -> 임원, 같은 부서). 저장하지 않고 그때그때 계산
def make_line(requester: dict, cache: dict | None = None):
    if cache is None:
        return approval_line(requester)
    key = (requester['e_team'], requester['e_jobtitle'])
    if key not in cache['lines']:
        cache['lines'][key] = approval_line(requester)
    return cache['lines'][key]


# 이 결재선으로 상신할 수 있는가: 신청자가 임원이거나, 결재선의 마지막 단계가 임원이어야 함
# (임원이 없는 부서는 결재가 끝나도 발주할 사람이 없으므로 상신을 막음)
def has_executive(requester: dict, line: list):
    if job_rank(requester['e_jobtitle']) >= EXEC_RANK:
        return True
    return bool(line) and job_rank(line[-1]['e_jobtitle']) == EXEC_RANK


# 품의서(approval) + 품의를 올리다(approval_request) 문서를 합치고, 결재선 등 계산 값을 붙인 하나의 dict로 만듦
def merge(a_seq: str, approval: dict, request: dict, cache: dict):
    info = requester_info(request.get('e_id'), cache)
    line = make_line(info, cache) if info else []
    return {
        **approval,
        **request,
        'a_seq': int(a_seq),
        'e_team': info['e_team'] if info else None,
        'e_jobtitle': info['e_jobtitle'] if info else None,
        'a_line': line,
    }


# 현재 서명 차례의 결재 단계 (모두 서명했으면 None)
def current_step(data: dict):
    line = data.get('a_line') or []
    step = data.get('a_step') or 1
    return line[step - 1] if step <= len(line) else None


# 이 직원이 지금 서명할 수 있는 품의인가
def can_sign(data: dict, employee: dict):
    if data.get('a_state') != STATE_REVIEW:
        return False
    step = current_step(data)
    return step is not None and employee['e_id'] in step['approvers']


# 이 직원이 발주할 수 있는 품의인가: 심사완료이고 아직 발주 전이며, 마지막 결재자(결재선이 없으면 신청자)인 임원이어야 함
def can_order(data: dict, employee: dict):
    if data.get('a_state') != STATE_DONE:
        return False
    if job_rank(employee['e_jobtitle']) < EXEC_RANK:
        return False
    signatures = data.get('a_signatures') or []
    last = signatures[-1]['e_id'] if signatures else data.get('e_id')
    return employee['e_id'] == last


def public_view(data: dict, employee: dict):
    return {
        **data,
        'can_sign': can_sign(data, employee),
        'can_order': can_order(data, employee),
        'ordered': data.get('a_state') == STATE_ORDERED,
        'is_mine': data.get('e_id') == employee['e_id'],
        'current_step': current_step(data),
    }
