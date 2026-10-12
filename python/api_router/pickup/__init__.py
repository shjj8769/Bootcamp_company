# python/APIRouter/pickup/__init__.py
# pickup 폴더의 입구 파일 (수령하다 = pick_up 테이블)
# → main.py에서 `from ApiRouter.pickup import pickup_router` 로 이 파일을 불러감
from fastapi import APIRouter

# 같은 폴더(.)의 각 파일에서 router를 가져와 이름을 구분해 둠
from .insert import router as insert_router   # 수령 처리
from .search import router as search_router   # 수령 조회

# pickup 전체를 아우르는 메인 라우터 생성
pickup_router = APIRouter()

# 각각의 하위 라우터들을 등록 (수령 기록은 이력이라 update/delete는 두지 않음)
# tags: /docs 화면에서 API를 묶어서 보여줄 그룹 이름
pickup_router.include_router(insert_router, tags=["Pickup Insert"])
pickup_router.include_router(search_router, tags=["Pickup Search"])
