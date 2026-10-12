from fastapi import FastAPI

from api_router.employee.employee import router as employee_router
from api_router.estimate.estimate import router as estimate_router
from api_router.inquire.inquire import router as inquire_router
from api_router.notice.notice import router as notice_router
from api_router.office_stock.office_stock import router as office_stock_router
from api_router.qr.qr import router as qr_router
from api_router.review.review import router as review_router
from api_router.store_stock.store_stock import router as store_stock_router

app = FastAPI()
app.include_router(employee_router, prefix='/employee', tags=['employee'])
app.include_router(estimate_router, prefix='/estimate', tags=['estimate'])
app.include_router(inquire_router, prefix='/inquire', tags=['inquire'])
app.include_router(notice_router, prefix='/notice', tags=['notice'])
app.include_router(office_stock_router, prefix='/office_stock', tags=['office_stock'])
app.include_router(qr_router, prefix='/qr', tags=['qr'])
app.include_router(review_router, prefix='/review', tags=['review'])
app.include_router(store_stock_router, prefix='/store_stock', tags=['store_stock'])
