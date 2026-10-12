# python/APIRouter/product/update.py
# 제품 수정 API → PUT /product/{SKU}
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import connect  # 공용 DB 연결 함수 (python/db.py)

router = APIRouter()


# 수정할 값 (SKU는 주소로 받음, pr_image는 별도 처리)
# SKU를 제외한 모든 컬럼을 한 번에 덮어씀 → 안 바꿀 값도 기존 값 그대로 보내야 함
class ProductUpdate(BaseModel):
    pr_code: str        # 모델 코드
    pr_name: str        # 제품명
    pr_brand: str       # 브랜드명
    pr_price: int       # 제품가격
    category: str       # 품목
    gender: str         # 성별
    size: int           # 사이즈
    color: str          # 색상


@router.put("/{SKU}")
def update_product(SKU: str, product: ProductUpdate):
    conn = connect()
    try:
        with conn.cursor() as curs:
            sql = """
                UPDATE product
                SET pr_code = %s, pr_name = %s, pr_brand = %s, pr_price = %s,
                    category = %s, gender = %s, size = %s, color = %s
                WHERE SKU = %s
            """
            curs.execute(sql, (
                product.pr_code,
                product.pr_name,
                product.pr_brand,
                product.pr_price,
                product.category,
                product.gender,
                product.size,
                product.color,
                SKU,  # WHERE 조건 (마지막 %s)
            ))
            # rowcount: 바뀐 행 수 → 0이면 해당 SKU가 없음
            if curs.rowcount == 0:
                raise HTTPException(status_code=404, detail="수정할 제품이 없습니다")
        conn.commit()  # 실제 DB에 저장 확정
        return {"result": "OK"}
    except HTTPException:
        raise  # 위에서 만든 404는 500으로 바뀌지 않게 그대로 전달
    except Exception as e:
        conn.rollback()  # 에러 시 변경 내용 되돌림
        raise HTTPException(status_code=500, detail=f"제품 수정 실패: {e}")
    finally:
        conn.close()  # DB 연결 종료
