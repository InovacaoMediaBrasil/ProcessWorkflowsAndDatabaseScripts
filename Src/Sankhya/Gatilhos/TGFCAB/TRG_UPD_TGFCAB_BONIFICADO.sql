USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_UPD_TGFCAB_BONIFICADO]    Script Date: 31/03/2017 14:31:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
 =============================================
 Author:   Rodrigo Lacalendola
 Create date: 2014-02-19
 Description: Zerar o valor dos itens pra pedidos bonificados. (Altera - TRG_UPT_TGFCAB_BONIFICADO).

 Author:   Rafael Turra
 Change date: 2017-03-30
 Description: 
 ============================================
*/

ALTER TRIGGER [sankhya].[TRG_UPD_TGFCAB_BONIFICADO] ON [sankhya].[TGFCAB] FOR UPDATE
AS
DECLARE
@NUNOTA  INT,
@CODTIPOPER INT,
@CODPARC INT,
@BONIFICADO VARCHAR(1),
@AD_DIGETIQ INT,
@CODTIPVENDA INT

BEGIN

 SELECT @CODTIPOPER = CODTIPOPER,
   @NUNOTA = NUNOTA,
   @CODPARC = CODPARC,
   @BONIFICADO = AD_BONIFICADO,
   @AD_DIGETIQ = AD_DIGETIQ
 FROM INSERTED 
 WHERE NUNOTA = @NUNOTA
 /* Verifica se é bonifica (tipo de venda) ou ad_bonificado = 'S'. Caso sim zerar os valores */


 IF (@CODTIPVENDA = 49 AND @CODTIPOPER = 503) OR (@CODTIPOPER = 504)
  BEGIN   
	IF ((SELECT TRIGGER_NESTLEVEL()) < 3 )
   BEGIN 
    UPDATE TGFCAB
    SET  VLRNOTA = 0.00,
      BASEICMS = 0.00,
      VLRICMS = 0.00,
      VLRFRETE = 0.00,
      VLRDESCTOT = 0.00,
      VLRDESCTOTITEM = 0.00,
      AD_BONIFICADO = CASE WHEN CODTIPOPER = 504 THEN 'S' ELSE 'N' END,
      AD_PAISETIQUETA = NULL,
      AD_NUMETIQ = NULL,
      AD_DIGETIQ = NULL
    WHERE NUNOTA = @NUNOTA

   END
  END
END