USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_IMP_PED_MANUAL_VTEX]    Script Date: 05/12/2016 18:54:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Guilherme Branco Stracini
-- Create date: 2016-12-05
-- Description:	Realiza a importação de um pedido manualmente, através da tela Pedidos c/ Importação Pendente.
-- =============================================
ALTER PROCEDURE [sankhya].[STP_IMP_PED_MANUAL_VTEX] (
       @P_CODUSU INT, 
       @P_IDSESSAO VARCHAR(4000),
       @P_QTDLINHAS INT,      
       @P_MENSAGEM VARCHAR(4000) OUT
) AS
DECLARE
       @PARAM_CODPED INT
BEGIN   
	SET @PARAM_CODPED = SANKHYA.ACT_INT_PARAM(@P_IDSESSAO, 'CODPED');
    IF EXISTS (SELECT 1 FROM sankhya.AD_IMPORTACAOPEDPENDENTE WHERE CODPED = @PARAM_CODPED)
		RAISERROR('O pedido %i já está na fila de importação, não é possível marcar como importação manual', 16, 1, @PARAM_CODPED);
	INSERT INTO sankhya.AD_IMPORTACAOPEDPENDENTE (CODPED, STATUS) VALUES (@PARAM_CODPED, 'M');  
END