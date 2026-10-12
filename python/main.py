from fastapi import FastAPI

from api_router.notice.notice import router as notice_router
from api_router.review.review import router as review_router
from api_router.payment import payment_router  # 구조화된 라우터 불러오기
from api_router.purchase import purchase_router  # 구매 라우터
from api_router.refund import refund_router    # 반품 라우터
from api_router.product import product_router  # 제품 라우터
from api_router.pickup import pickup_router    # 수령 라우터
from api_router.hq_return import hq_return_router  # 반납 라우터 (대리점 → 본사)

app = FastAPI()
app.include_router(notice_router, prefix='/notice', tags=['notice'])
app.include_router(review_router, prefix='/review', tags=['review'])
app.include_router(payment_router, prefix='/payment', tags=['payment'])
app.include_router(purchase_router, prefix='/purchase', tags=['purchase'])
app.include_router(refund_router, prefix='/refund', tags=['refund'])
app.include_router(product_router, prefix='/product', tags=['product'])
app.include_router(pickup_router, prefix='/pickup', tags=['pickup'])
app.include_router(hq_return_router, prefix='/hq_return', tags=['hq_return'])
