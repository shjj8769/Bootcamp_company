from google.cloud import firestore

# 재고 컬렉션 (Firestore). 재고 단위는 SKU(사이즈/색상)이고 pr_id = SKU
OFFICE = 'office_pr_count'   # 본사재고, 문서 ID = SKU
STORE = 'store_pr_count'     # 대리점재고, 문서 ID = {store_seq}_{SKU}, store_seq = MySQL store.seq
SEND = 'send'                # 본사 -> 대리점 발송
RECEIPT = 'receipt'          # 제조사 수주

# 기준재고 100개 고정, 최소수량은 기준재고의 30%
BASE_COUNT = 100
LEAST_COUNT = int(BASE_COUNT * 0.3)


def store_doc_id(store_seq: int, pr_id: str):
    return '{}_{}'.format(store_seq, pr_id)


# 재고가 최소수량(30%) 미만이면 제조사에 발주 요청 필요
def need_order(now_count, least_count=LEAST_COUNT):
    return int(now_count or 0) < int(least_count)


def now():
    return firestore.SERVER_TIMESTAMP
