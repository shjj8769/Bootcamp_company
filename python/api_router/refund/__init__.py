# python/APIRouter/refund/__init__.py
# refund 폴더의 입구 파일
# → main.py에서 `from ApiRouter.refund import refund_router` 로 이 파일을 불러감
from fastapi import APIRouter

# 같은 폴더(.)의 각 파일에서 router를 가져와 이름을 구분해 둠
from .insert import router as insert_router   # 반품 접수
from .search import router as search_router   # 반품 조회
from .update import router as update_router   # 환불 처리

# refund 전체를 아우르는 메인 라우터 생성
refund_router = APIRouter()

# 각각의 하위 라우터들을 등록 (반품 기록은 이력이라 delete는 두지 않음)
# tags: /docs 화면에서 API를 묶어서 보여줄 그룹 이름
refund_router.include_router(insert_router, tags=["Refund Insert"])
refund_router.include_router(search_router, tags=["Refund Search"])
refund_router.include_router(update_router, tags=["Refund Update"])
