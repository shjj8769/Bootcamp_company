from fastapi import FastAPI

from api_router.notice.notice import router as notice_router

app = FastAPI()
app.include_router(notice_router, prefix='/notice', tags=['notice'])
