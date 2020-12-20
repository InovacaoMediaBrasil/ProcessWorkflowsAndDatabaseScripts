-- ================================================
-- Template generated from Template Explorer using:
-- Create Procedure (New Menu).SQL
--
-- Use the Specify Values for Template Parameters 
-- command (Ctrl-Shift-M) to fill in the parameter 
-- values below.
--
-- This block of comments will not be included in
-- the definition of the procedure.
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Guilherme Branco Stracini
-- Create date: 2014-05-30
-- Description:	Altera o campo STATUSNFE na TGFCAB para permitir correção de NF-e com status Enviada e sem itens
-- =============================================
CREATE PROCEDURE STP_ALTERASTATUSNFEENVIADA 
	-- Add the parameters for the stored procedure here
	@Return_Message VARCHAR(1024) = ''  OUT,
	@NUNOTA INT = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @ErrorCode INT
	
	SELECT @ErrorCode = @@ERROR

	BEGIN TRY

		BEGIN TRAN
			ALTER TABLE sankhya.TGFCAB DISABLE TRIGGER ALL;
			ALTER TABLE sankhya.TGFCAB NOCHECK CONSTRAINT ALL;
			UPDATE sankhya.TGFCAB SET STATUSNFE = 'M' WHERE NUNOTA = @NUNOTA;
			ALTER TABLE sankhya.TGFCAB CHECK CONSTRAINT ALL;
			ALTER TABLE sankhya.TGFCAB ENABLE TRIGGER ALL;
			
			SELECT  @ErrorCode = 0, @Return_Message = 'Status NF-e alterado para M com sucesso na nota: ' + cast(@NUNOTA AS VARCHAR(20))
		COMMIT TRAN

	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 
			ROLLBACK
		
		SELECT @ErrorCode = ERROR_NUMBER(), 
		@Return_Message = CAST(ERROR_NUMBER() AS VARCHAR(20)) + ' linha: '
        + CAST(ERROR_LINE() AS VARCHAR(20)) + ' ' 
        + ERROR_MESSAGE() + ' > ' 
        + ERROR_PROCEDURE()
		
		RETURN @ErrorCode   
	END CATCH
END
GO
