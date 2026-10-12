# python/APIRouter/payment/__init__.py
# payment 폴더의 입구 파일
# → main.py에서 `from ApiRouter.payment import payment_router` 로 이 파일을 불러감
from fastapi import APIRouter

# 같은 폴더(.)의 각 파일에서 router를 가져와 이름을 구분해 둠
from .insert import router as insert_router   # 결제 등록
from .search import router as search_router   # 결제 조회
from .update import router as update_router   # 결제 수정
from .delete import router as delete_router   # 결제 삭제

# payment 전체를 아우르는 메인 라우터 생성
payment_router = APIRouter()

# 각각의 하위 라우터들을 등록 (필요시 tags나 prefix 분리 가능)
# tags: /docs 화면에서 API를 묶어서 보여줄 그룹 이름
payment_router.include_router(insert_router, tags=["Payment Insert"])
payment_router.include_router(search_router, tags=["Payment Search"])
payment_router.include_router(update_router, tags=["Payment Update"])
payment_router.include_router(delete_router, tags=["Payment Delete"])
