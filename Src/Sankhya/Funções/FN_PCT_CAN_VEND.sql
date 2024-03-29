USE [SANKHYA_PRODUCAO]
GO
/****** Object:  UserDefinedFunction [sankhya].[FN_PCT_CAN_VEND]    Script Date: 15/03/2017 17:02:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		RODRIGO LACALENDOLA
-- Create date: 2015-01-28
-- Description:	CALCULA A PORCENTAGEM DE PEDIDOS CANCELADOS SOBRE O TOTAL DE PEDIDOS DE UM VENDEDOR
-- =============================================
ALTER FUNCTION [sankhya].[FN_PCT_CAN_VEND]
(
	-- Add the parameters for the function here
	@CODVEND INT, @DTINI DATE, @DTFIM DATE, @CODTIPOPER INT
)
RETURNS DECIMAL(8,2)
AS
BEGIN

	DECLARE @PORC DECIMAL(8,2), @PEDIDOS DECIMAL(8,2), @CANCELADOS DECIMAL(8,2)

	/* Selecionando pedidos cancelados automaticamente pelo IntegracaoService (motivo cancelamento sempre começa com 'Pedido sem pagamento'*/
	select @CANCELADOS = COUNT(EXC.NUNOTA)
	from sankhya.TGFCAN CAN
	INNER JOIN sankhya.TGFCAB_EXC EXC ON EXC.NUNOTA = CAN.NUNOTA
	where CODTIPOPER = @CODTIPOPER AND EXC.DTNEG >= @DTINI AND EXC.DTNEG <=@DTFIM and CODVEND = @CODVEND AND CAN.MOTCANCEL like '%Pedido%sem%pagamento%'


	/*Selecionando pedidos na TGFCAB do vendedor*/
	select @PEDIDOS = COUNT(NUNOTA)
	from sankhya.TGFCAB 
	where CODTIPOPER = @CODTIPOPER AND DTNEG >= @DTINI AND DTNEG <=@DTFIM and CODVEND = @CODVEND

	/* Cálculo da porcentagem de cancelamento */
	SELECT @PORC =  ROUND(((@CANCELADOS/(@CANCELADOS+@PEDIDOS))*100.0),2)
	 
	RETURN @PORC

END
