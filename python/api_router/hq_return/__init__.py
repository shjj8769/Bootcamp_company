# python/APIRouter/hq_return/__init__.py
# hq_return 폴더의 입구 파일 (반납하다 = return 테이블, 대리점 → 본사)
# 폴더 이름을 return으로 하면 Python 예약어라 import가 안 되므로 hq_return 사용
# → main.py에서 `from ApiRouter.hq_return import hq_return_router` 로 이 파일을 불러감
from fastapi import APIRouter

# 같은 폴더(.)의 각 파일에서 router를 가져와 이름을 구분해 둠
from .insert import router as insert_router   # 반납 등록
from .search import router as search_router   # 반납 조회

# hq_return 전체를 아우르는 메인 라우터 생성
hq_return_router = APIRouter()

# 각각의 하위 라우터들을 등록 (반납 기록은 이력이라 update/delete는 두지 않음)
# tags: /docs 화면에서 API를 묶어서 보여줄 그룹 이름
hq_return_router.include_router(insert_router, tags=["HqReturn Insert"])
hq_return_router.include_router(search_router, tags=["HqReturn Search"])
