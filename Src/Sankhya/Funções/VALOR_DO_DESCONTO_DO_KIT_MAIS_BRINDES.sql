USE [SANKHYA_PRODUCAO]
GO
/****** Object:  UserDefinedFunction [sankhya].[VALOR_DO_DESCONTO_DO_KIT_MAIS_BRINDES]    Script Date: 15/03/2017 17:03:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		rodrigo lacalendola
-- Create date: 2016-09-16
-- Description:	obtem o valor dos DESCONTOS de um kit no pedido
-- =============================================
ALTER FUNCTION [sankhya].[VALOR_DO_DESCONTO_DO_KIT_MAIS_BRINDES]
(
	@NUNOTA INT,
	@SEQUENCIA INT
)
RETURNS FLOAT
AS
BEGIN

	DECLARE @VLR FLOAT

	-- OBTEM OS DADOS DO DESCONTOS DOS ITENS DO KIT MAIS OS DEVIDOS BRINDES ASSOCIADOS À ELE
	select @VLR = VLR.VLR from sankhya.TGFCAB CAB WITH(NOLOCK)
	INNER JOIN sankhya.TGFITE ITE WITH(NOLOCK) ON ITE.NUNOTA = CAB.NUNOTA AND USOPROD = 'R' AND CODVOL = 'KT'
	LEFT JOIN (select SEQUENCIAORIG, SUM(VLRDESC) AS VLR from sankhya.TGFCAB CAB WITH(NOLOCK)
	INNER JOIN sankhya.TGFITE ITE WITH(NOLOCK) ON ITE.NUNOTA = CAB.NUNOTA AND ITE.USOPROD = 'D'
	INNER JOIN sankhya.TGFVAR V WITH(NOLOCK) ON V.NUNOTA = ITE.NUNOTA AND V.SEQUENCIA = ITE.SEQUENCIA AND V.NUNOTAORIG = V.NUNOTA
	where cab.nunota = @NUNOTA
	GROUP BY SEQUENCIAORIG) VLR ON VLR.SEQUENCIAORIG = ITE.SEQUENCIA
	where cab.nunota = @NUNOTA AND ITE.SEQUENCIA = @SEQUENCIA


	RETURN @VLR


END
