from fastapi import APIRouter, Depends
from google.cloud.firestore_v1.base_query import FieldFilter

from api_router.employee.auth_employee import get_db, require_store
from api_router.office_stock.stock_common import STORE

router = APIRouter()


# 대리점 재고 목록: 로그인한 대리점 직원의 store_seq 재고만 조회
@router.get("")
async def list_store_stock(employee: dict = Depends(require_store)):

    try:
        docs = get_db().collection(STORE).where(
            filter=FieldFilter('store_seq', '==', employee['store_seq'])
        ).stream()
        rows = [d.to_dict() for d in docs if d.id != '_erd']
        rows.sort(key=lambda r: r.get('pr_id', ''))
        return {'results': rows}

    except Exception as e:
        print("Error:", e)
        return {'result': 'Error'}
