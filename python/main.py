from fastapi import FastAPI

from api_router.notice.notice import router as notice_router
from api_router.review.review import router as review_router

app = FastAPI()
app.include_router(notice_router, prefix='/notice', tags=['notice'])
app.include_router(review_router, prefix='/review', tags=['review'])
