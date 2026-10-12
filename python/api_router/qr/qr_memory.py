import time

# 픽업 QR은 5분짜리 휘발성 데이터라 DB에 저장하지 않고 서버 메모리에 보관
# 서버를 재시작하면 발급된 QR은 모두 사라지고, 워커를 여러 개 띄우면 공유되지 않음
QR_EXPIRE_SECONDS = 60 * 5

# {난수 코드: {p_id, email, store_seq, pr_id, count, expires_at}}
_codes = {}
# 픽업이 끝난 주문번호 (같은 주문의 QR 재발급 방지)
_picked = set()


def purge():
    now = time.time()
    for code in [c for c, v in _codes.items() if v['expires_at'] < now]:
        del _codes[code]


# 같은 주문의 이전 QR은 지우고 새 QR 저장
def save(code, info):
    purge()
    for old in [c for c, v in _codes.items() if v['p_id'] == info['p_id']]:
        del _codes[old]
    _codes[code] = {**info, 'expires_at': time.time() + QR_EXPIRE_SECONDS}


def get(code):
    purge()
    return _codes.get(code)


# 사용 처리: 코드를 지우고 주문을 픽업 완료로 기록
def use(code):
    info = _codes.pop(code, None)
    if info is not None:
        _picked.add(info['p_id'])


def is_picked(p_id):
    return p_id in _picked
