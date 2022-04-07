class EncodeAzulFilesNames < Mongoid::Migration
    def self.up
      download_reqs = DownloadRequest.where(:azul_files.ne => nil)
      download_reqs.each do |req|
        encoded_azul_files = DownloadRequest.transform_files(req.azul_files, :encode)
        req.update(azul_files: encoded_azul_files)
      end
    end
  
    def self.down
    download_reqs = DownloadRequest.where(:azul_files.ne => nil)
    download_reqs.each do |req|
        decoded_azul_files = DownloadRequest.transform_files( req.azul_files, :decode)
        req.update(azul_files: decoded_azul_files)
      end
    end
  end
  