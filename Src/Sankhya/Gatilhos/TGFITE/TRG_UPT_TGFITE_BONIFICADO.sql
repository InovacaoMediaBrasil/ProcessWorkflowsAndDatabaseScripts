USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_UPD_TGFITE_BONIFICADO]    Script Date: 31/03/2017 13:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* =============================================
 Author:   Rodrigo Lacalendola
 Create date: 19/02/2014
 Description: Zerar o valor dos itens pra pedidos bonificados (Altera - TRG_UPT_TGFITE_BONIFICADO)

 Author:   Rafael Turra
 Change date: 2017-03-30
 Description: 
 ============================================
*/

ALTER TRIGGER [sankhya].[TRG_UPD_TGFITE_BONIFICADO] ON [sankhya].[TGFITE] AFTER INSERT,UPDATE
AS
DECLARE
@NUNOTA  INT,
@CODPARC INT,
@CODTIPOPER INT,
@UF   VARCHAR(2),
@CODTIPVENDA INT,
@SEQUENCIA INT

/* obtem o NUNOTA e o CODPARC do movimento inserido */
SELECT	@NUNOTA = INSERTED.NUNOTA,
		@CODPARC = CAB.CODPARC,
		@CODTIPOPER = CAB.CODTIPOPER,
		@CODTIPVENDA = CAB.CODTIPVENDA,
		@SEQUENCIA = SEQUENCIA
FROM	INSERTED 
		INNER JOIN TGFCAB CAB ON CAB.NUNOTA = INSERTED.NUNOTA AND ((CAB.CODTIPVENDA = 49 AND CAB.CODTIPOPER = 503) OR CAB.CODTIPOPER = 504)

BEGIN
/* obtem a UF que ser� usada posteriormente para o c�digo CFOP */
 IF @CODTIPOPER = 504
	BEGIN 
	UPDATE TGFCAB SET AD_BONIFICADO = 'S'
	WHERE NUNOTA = @NUNOTA
	END
 
 SET @UF = ( SELECT UF.UF
    FROM	sankhya.TGFPAR PAR
			INNER JOIN sankhya.TSICID CID ON (CID.CODCID = PAR.CODCID)
			INNER JOIN sankhya.TSIUFS UF ON (UF.CODUF = CID.UF)
    WHERE	CODPARC = @CODPARC)
 
 /* verifica se n�o existe aninhamento (triggers aninhadas) e executa o update */
 IF ((SELECT TRIGGER_NESTLEVEL()) < 2 )
  BEGIN
   IF (@CODTIPOPER != 600)
    BEGIN
     UPDATE TGFITE
     SET  PERCDESC = CASE WHEN USOPROD = 'D' THEN PERCDESC ELSE 100 END,
       VLRDESC = CASE WHEN USOPROD = 'D' THEN VLRDESC ELSE VLRTOT END,
       VLRICMS = 0,
       BASEICMS = 0,
       BASICMMOD = NULL,
       CODCFO = CASE WHEN @UF = 'SP' THEN 5910 ELSE 6910 END
     WHERE	NUNOTA = @NUNOTA
			AND SEQUENCIA = @SEQUENCIA
			AND USOPROD IN ('R','D')
    END
     
   IF @CODTIPOPER = 600
    BEGIN
     UPDATE TGFITE
     SET	PERCDESC = CASE WHEN USOPROD = 'D' THEN PERCDESC ELSE 100 END,
			VLRDESC = CASE WHEN USOPROD = 'D' THEN VLRDESC ELSE VLRTOT END,
			VLRICMS = 0,
			BASEICMS = 0,
			BASICMMOD = NULL,
			CODCFO = CASE WHEN @UF = 'SP' THEN 1202 ELSE 2202 END
     WHERE	NUNOTA = @NUNOTA
			AND SEQUENCIA = @SEQUENCIA
			AND USOPROD IN ('R','D')
    END

	UPDATE	TGFDIN
	SET		VALOR = 0.00,
			BASERED = 0.00,
			VLRCRED=0,
			VLRDIFALDEST = 0,
			VLRDIFALREM=0,
			VLRFCP=0,
			PERCFCP=0,
			PERCPARTDIFAL=0,
			ALIQINTDEST=0
   WHERE	NUNOTA = @NUNOTA AND SEQUENCIA = @SEQUENCIA   
   
   END
END