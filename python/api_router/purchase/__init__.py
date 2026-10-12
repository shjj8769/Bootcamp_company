# python/APIRouter/purchase/__init__.py
# purchase 폴더의 입구 파일 (구매하다 = purchase 테이블)
# → main.py에서 `from ApiRouter.purchase import purchase_router` 로 이 파일을 불러감
from fastapi import APIRouter

# 같은 폴더(.)의 각 파일에서 router를 가져와 이름을 구분해 둠
from .insert import router as insert_router   # 구매 등록
from .search import router as search_router   # 구매 조회
from .update import router as update_router   # 구매 수정
from .delete import router as delete_router   # 구매 삭제

# purchase 전체를 아우르는 메인 라우터 생성
purchase_router = APIRouter()

# 각각의 하위 라우터들을 등록 (필요시 tags나 prefix 분리 가능)
# tags: /docs 화면에서 API를 묶어서 보여줄 그룹 이름
purchase_router.include_router(insert_router, tags=["Purchase Insert"])
purchase_router.include_router(search_router, tags=["Purchase Search"])
purchase_router.include_router(update_router, tags=["Purchase Update"])
purchase_router.include_router(delete_router, tags=["Purchase Delete"])
