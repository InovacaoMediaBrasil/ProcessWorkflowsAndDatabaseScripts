USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_PROXIMO_RANGE_AUTOMATICO]    Script Date: 04/04/2017 16:02:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Rodrigo Lacalendola
	Create date:	2014-09-16
	Description:	Idenfitica quando o range de etiquetas acaba e ativa o próximo range caso exista.

	Author			Guilherme Branco Stracini
	Change date:	2016-12-10
	Description:	Correção na declaração das variáveis, adicionado WITH (NOLOCK) nos selects, e melhorado performance (menos SELECTs)

	Author:			Guilherme Branco Stracini
	Change date:	2017-04-04
	Description:	Renomeado trigger de TRG_PROXIMO_RANGE_AUTOMATICO para TRG_UPD_AD_EXPEDICAO (padrão de nomenclatura dos gatilhos)

 =============================================*/

ALTER TRIGGER [sankhya].[TRG_UPD_AD_EXPEDICAO]
	ON  [SANKHYA_PRODUCAO].[sankhya].[AD_EXPEDICAO]
	AFTER UPDATE
AS 
DECLARE
@SALDO INT,
@IDEXP INT,
@IDMOD INT,
@IDEXPPROX INT
BEGIN
	SET NOCOUNT ON;
	SELECT @SALDO = SALDO, @IDEXP = IDEXP, @IDMOD = IDMOD  FROM INSERTED;	
	IF @SALDO > 0
		RETURN;
	SET @IDEXPPROX =  (SELECT TOP 1 IDEXP FROM sankhya.AD_EXPEDICAO WITH (NOLOCK) WHERE IDEXP > @IDEXP AND IDMOD = @IDMOD AND SALDO > 0)
	IF @IDEXPPROX IS NULL
		RETURN;
	UPDATE sankhya.AD_EXPEDICAO SET SEQATUAL = 'N' WHERE IDEXP = @IDEXP
	UPDATE sankhya.AD_EXPEDICAO SET SEQATUAL = 'S' WHERE IDEXP = @IDEXPPROX
END
